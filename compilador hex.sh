#!/bin/bash

# --- Verificar dependencias ---
FALTAN=""

! command -v zenity &> /dev/null && FALTAN+="Zenity\n"
! command -v avrdude &> /dev/null && FALTAN+="Avrdude\n"

if [ -n "$FALTAN" ]; then
    zenity --error --text="❌ Faltan los siguientes programas requeridos:\n\n$FALTAN\nPor favor instálalos antes de continuar."
    exit 1
fi

# --- Función para reinvocar con sudo si no hay permisos sobre el puerto ---
reinvocar_con_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo "Reintentando con permisos de administrador..."
        exec sudo "$0"
        exit
    fi
}

# --- Seleccionar archivo .hex ---
HEX_FILE=$(zenity --file-selection --title="Selecciona el archivo .hex" \
           --file-filter="*.hex" \
           --file-filter="Todos los archivos (*)")
[ -z "$HEX_FILE" ] && exit 1

# --- Detectar puertos disponibles ---
PORTS=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null)
if [ -z "$PORTS" ]; then
    zenity --error --text="No se encontraron dispositivos /dev/ttyUSB* ni /dev/ttyACM* conectados."
    exit 1
fi

PORT_LIST=$(for p in $PORTS; do echo "$p"; done)

PORT=$(echo "$PORT_LIST" | zenity --list --title="Selecciona el puerto del Arduino" --column="Puertos disponibles")
[ -z "$PORT" ] && exit 1

# --- Verificar permisos sobre el puerto ---
if [ ! -w "$PORT" ]; then
    zenity --question --text="El script no tiene permisos para acceder a $PORT.\n¿Deseas continuar con privilegios de administrador?"
    [ $? -eq 0 ] && reinvocar_con_sudo
    exit 1
fi

# --- Pedir baud rate ---
BAUD=$(zenity --entry --title="Velocidad de transmisión (baud rate)" \
       --text="Introduce el baud rate (ej. 115200). Deja vacío para usar 115200 por defecto:")
[ -z "$BAUD" ] && BAUD=115200

# --- Ejecutar avrdude ---
avrdude -v -patmega328p -carduino -P"$PORT" -b"$BAUD" -D -Uflash:w:"$HEX_FILE":i

# --- Mostrar resultado ---
if [ $? -eq 0 ]; then
    zenity --info --text="✔️ Archivo cargado con éxito en $PORT a $BAUD baudios"
else
    zenity --error --text="❌ Error al cargar el archivo en $PORT"
fi
