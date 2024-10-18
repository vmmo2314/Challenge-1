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
    
    # RAM (en MB)
    RAM_MB=$(dialog --stdout --title "Configuración de la VM" --inputbox "Cantidad de RAM en MB (por defecto 1024):" 8 40)
    RAM_MB=${RAM_MB:-1024}
    
    # VRAM (en MB)
    VRAM_MB=$(dialog --stdout --title "Configuración de la VM" --inputbox "Cantidad de VRAM en MB (por defecto 16):" 8 40)
    VRAM_MB=${VRAM_MB:-16}
    
    # Tamaño del disco virtual (en MB)
    DISK_SIZE=$(dialog --stdout --title "Configuración de la VM" --inputbox "Tamaño del disco duro en MB (por defecto 10240):" 8 40)
    DISK_SIZE=${DISK_SIZE:-10240}
    
    # Directorio de exportación
    EXPORT_DIR=$(dialog --stdout --title "Configuración de la VM" --inputbox "Directorio para exportar la VM (por defecto actual):" 8 40)
    EXPORT_DIR=${EXPORT_DIR:-$(pwd)}
}

# Función para crear y configurar la VM
create_vm() {
    # Crear máquina virtual
    (
        echo "10" ; sleep 1
        VBoxManage createvm --name "$VM_NAME" --ostype "$OS_TYPE" --register
        echo "20" ; sleep 1
        
        # Configurar CPU, RAM y VRAM
        VBoxManage modifyvm "$VM_NAME" --cpus "$CPU_COUNT" --memory "$RAM_MB" --vram "$VRAM_MB"
        echo "40" ; sleep 1
        
        # Crear disco duro virtual
        DISK_FILE="${VM_NAME}_disk.vdi"
        VBoxManage createmedium disk --filename "$DISK_FILE" --size "$DISK_SIZE" --format VDI
        echo "60" ; sleep 1
        
        # Crear y asociar el controlador SATA
        VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
        VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$DISK_FILE"
        echo "80" ; sleep 1
        
        # Crear y asociar el controlador IDE
        VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
        VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium emptydrive
        echo "90" ; sleep 1

        # Exportar la VM en formato OVF
        EXPORT_CMD="VBoxManage export \"$VM_NAME\" --output \"${EXPORT_DIR}/${VM_NAME}.ovf\" --ovf20"
        echo "Ejecutando comando de exportación: $EXPORT_CMD"
        EXPORT_OUTPUT=$(eval $EXPORT_CMD 2>&1)
        EXPORT_STATUS=$?

        if [ $EXPORT_STATUS -ne 0 ]; then
            dialog --title "Error de Exportación" --msgbox "Error al exportar la VM:\n$EXPORT_OUTPUT" 15 60
            exit 1
        fi
        echo "100" ; sleep 1
    ) | dialog --title "Creando VM" --gauge "Por favor espere..." 8 50 0

    # Verificar la existencia del archivo OVF
    if [ ! -f "${EXPORT_DIR}/${VM_NAME}.ovf" ]; then
        dialog --title "Error" --msgbox "El archivo OVF no se creó correctamente.\nVerifique los permisos y el espacio en disco." 8 60
        exit 1
    fi

    # Mostrar contenido del directorio de exportación
    DIR_CONTENT=$(ls -l "${EXPORT_DIR}")
    dialog --title "Contenido del Directorio" --msgbox "Contenido de ${EXPORT_DIR}:\n$DIR_CONTENT" 15 60

    # Mostrar la información de la VM exportada
    dialog --title "Información de la VM" --msgbox "Máquina virtual exportada exitosamente.\nUbicación: ${EXPORT_DIR}/${VM_NAME}.ovf" 8 60
}

# Función principal
main() {
    show_banner
    request_config
    create_vm
    dialog --title "Éxito" --msgbox "¡Máquina virtual creada y exportada exitosamente" 8 60
}

# Limpiar la pantalla antes de salir
trap clear EXIT

# Ejecutar el script
main

exit 0