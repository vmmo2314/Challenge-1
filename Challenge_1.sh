#!/usr/bin/env bash

# Comprobar si dialog está instalado
if ! command -v dialog &> /dev/null; then
    clear
    echo "El paquete 'dialog' no está instalado. Por favor, instálalo para continuar."
    echo "En sistemas basados en Debian/Ubuntu, puedes instalarlo con:"
    echo "sudo apt-get install dialog"
    exit 1
fi

# Comprobar si VBoxManage está disponible
if ! command -v VBoxManage &> /dev/null; then
    clear
    dialog --title "Error" --msgbox "VBoxManage no está disponible. Por favor, instala VirtualBox antes de continuar." 8 50
    clear
    exit 1
fi

# Función para mostrar el banner
show_banner() {
    dialog --title "VirtualBox VM Creator" \
           --msgbox "Bienvenido al Creador de Máquinas Virtuales de VirtualBox" 8 60
}

# Función para solicitar la configuración de la VM
request_config() {
    # Nombre de la VM
    VM_NAME=$(dialog --stdout --title "Configuración de la VM" --inputbox "Nombre de la máquina virtual:" 8 40)
    VM_NAME=${VM_NAME:-"DefaultVM"}
    
    # Tipo de sistema operativo
    OS_TYPE=$(dialog --stdout --title "Configuración de la VM" --inputbox "Sistema Operativo (ej. Ubuntu_64, Fedora_64):" 8 40)
    OS_TYPE=${OS_TYPE:-"Linux_64"}
    
    # Número de CPUs
    CPU_COUNT=$(dialog --stdout --title "Configuración de la VM" --inputbox "Número de CPUs (por defecto 2):" 8 40)
    CPU_COUNT=${CPU_COUNT:-2}
    
    # RAM (en GB)
    RAM_GB=$(dialog --stdout --title "Configuración de la VM" --inputbox "Cantidad de RAM en GB (por defecto 2):" 8 40)
    RAM_GB=${RAM_GB:-2}
    RAM_MB=$((RAM_GB * 1024))
    
    # VRAM (en MB)
    VRAM_MB=$(dialog --stdout --title "Configuración de la VM" --inputbox "Cantidad de VRAM en MB (por defecto 16):" 8 40)
    VRAM_MB=${VRAM_MB:-16}
    
    # Tamaño del disco virtual (en GB)
    DISK_SIZE_GB=$(dialog --stdout --title "Configuración de la VM" --inputbox "Tamaño del disco duro en GB (por defecto 10):" 8 40)
    DISK_SIZE_GB=${DISK_SIZE_GB:-10}
    DISK_SIZE=$((DISK_SIZE_GB * 1024))
    
    # Nombre del controlador SATA
    SATA_CONTROLLER=$(dialog --stdout --title "Configuración de la VM" --inputbox "Nombre del controlador SATA:" 8 40)
    SATA_CONTROLLER=${SATA_CONTROLLER:-"SATA Controller"}
    
    # Nombre del controlador IDE
    IDE_CONTROLLER=$(dialog --stdout --title "Configuración de la VM" --inputbox "Nombre del controlador IDE:" 8 40)
    IDE_CONTROLLER=${IDE_CONTROLLER:-"IDE Controller"}
    
    # Directorio de exportación
    EXPORT_DIR=$(dialog --stdout --title "Configuración de la VM" --inputbox "Directorio para exportar la VM (por defecto actual):" 8 40)
    EXPORT_DIR=${EXPORT_DIR:-$(pwd)}
}

# Función para crear y configurar la VM
create_vm() {
    (
        echo "10" ; sleep 1
        VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register
        echo "20" ; sleep 1
        
        VBoxManage modifyvm "$VM_NAME" --cpus "$CPU_COUNT" --memory "$RAM_MB" --vram "$VRAM_MB"
        echo "40" ; sleep 1
        
        DISK_FILE="${VM_NAME}_disk.vdi"
        VBoxManage createmedium disk --filename "$DISK_FILE" --size "$DISK_SIZE" --format VDI
        echo "60" ; sleep 1
        
        VBoxManage storagectl "$VM_NAME" --name "$SATA_CONTROLLER" --add sata --controller IntelAhci
        VBoxManage storageattach "$VM_NAME" --storagectl "$SATA_CONTROLLER" --port 0 --device 0 --type hdd --medium "$DISK_FILE"
        echo "80" ; sleep 1
        
        VBoxManage storagectl "$VM_NAME" --name "$IDE_CONTROLLER" --add ide
        VBoxManage storageattach "$VM_NAME" --storagectl "$IDE_CONTROLLER" --port 0 --device 0 --type dvddrive --medium emptydrive
        echo "90" ; sleep 1

        EXPORT_CMD="VBoxManage export \"$VM_NAME\" --output \"${EXPORT_DIR}/${VM_NAME}.ovf\" --ovf20"
        EXPORT_OUTPUT=$(eval $EXPORT_CMD 2>&1)
        EXPORT_STATUS=$?

        if [ $EXPORT_STATUS -ne 0 ]; then
            dialog --title "Error de Exportación" --msgbox "Error al exportar la VM:\n$EXPORT_OUTPUT" 15 60
            exit 1
        fi
        echo "100" ; sleep 1
    ) | dialog --title "Creando VM" --gauge "Por favor espere..." 8 50 0

    if [ ! -f "${EXPORT_DIR}/${VM_NAME}.ovf" ]; then
        dialog --title "Error" --msgbox "El archivo OVF no se creó correctamente.\nVerifique los permisos y el espacio en disco." 8 60
        exit 1
    fi

    DIR_CONTENT=$(ls -l "${EXPORT_DIR}")
    dialog --title "Contenido del Directorio" --msgbox "Contenido de ${EXPORT_DIR}:\n$DIR_CONTENT" 15 60

    show_vm_config
}

# Función para mostrar la configuración de la VM de forma concisa
show_vm_config() {
    CONFIG_INFO="\
Nombre de la máquina virtual: $VM_NAME
Tipo de sistema operativo: $OS_TYPE
Número de CPUs: $CPU_COUNT
Memoria RAM: ${RAM_GB} GB
VRAM: ${VRAM_MB} MB
Tamaño del disco duro: ${DISK_SIZE_GB} GB
Controlador SATA: $SATA_CONTROLLER
Controlador IDE: $IDE_CONTROLLER"

    dialog --title "Configuración de la VM" --msgbox "$CONFIG_INFO" 15 60
}

# Función principal
main() {
    show_banner
    request_config
    create_vm
    dialog --title "Éxito" --msgbox "¡Máquina virtual creada y exportada exitosamente!" 8 60
}

# Limpiar la pantalla antes de salir
trap clear EXIT

# Ejecutar el script
main

exit 0
