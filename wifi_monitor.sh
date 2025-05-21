#!/bin/bash

# Este script requiere permisos de root para funcionar correctamente.
# Por favor, ejecútalo siempre con: sudo ./wifi_monitor.sh

echo "Iniciando escaneo de redes en modo monitor..."

# Define la interfaz de monitoreo. Asumimos wlan0mon, pero se puede ajustar si airmon-ng la cambia.
MONITOR_INTERFACE="wlan0mon"
OUTPUT_PREFIX="redes_detectadas"
CSV_FILE="${OUTPUT_PREFIX}-01.csv" # Nombre esperado del archivo CSV

# --- Función para limpiar archivos temporales al salir o interrumpir el script ---
cleanup() {
    echo ""
    echo "Realizando limpieza de archivos temporales..."
    # Elimina todos los archivos generados por airodump-ng con el prefijo
    rm -f "${OUTPUT_PREFIX}-"*.csv "${OUTPUT_PREFIX}-"*.kismet.csv "${OUTPUT_PREFIX}-"*.kismet.netxml 2>/dev/null
    echo "Limpieza completada."
    # Opcional: Si quieres detener el modo monitor al finalizar, descomenta la siguiente línea.
    # sudo airmon-ng stop wlan0mon > /dev/null 2>&1
}

# Configura el trap para llamar a la función cleanup en caso de salida (EXIT) o interrupción (INT, TERM)
trap cleanup EXIT INT TERM

# Verifica si la interfaz monitor está activa. Si no, intenta activarla.
if ! ip link show "$MONITOR_INTERFACE" &> /dev/null; then
    echo "⚠️ $MONITOR_INTERFACE no está activa. Intentando activarla..."

    # Intenta matar procesos que interfieren con el modo monitor
    echo "Ejecutando: sudo airmon-ng check kill"
    sudo airmon-ng check kill || { echo "❌ Error al ejecutar airmon-ng check kill. Saliendo."; exit 1; }
    
    echo "Ejecutando: sudo airmon-ng start wlan0"
    # Captura la salida de airmon-ng start para identificar la interfaz monitorizada.
    # Esto es crucial porque a veces airmon-ng puede crear una interfaz con un nombre diferente (ej. wlan1mon).
    # Usamos grep y awk para extraer el nombre de la interfaz.
    ACTIVATION_OUTPUT=$(sudo airmon-ng start wlan0 2>&1)
    NEW_MONITOR_INTERFACE=$(echo "$ACTIVATION_OUTPUT" | grep "monitor mode enabled" | awk '{print $NF}' | tr -d '[:punct:]') # Elimina paréntesis y otros signos

    if [ -n "$NEW_MONITOR_INTERFACE" ] && ip link show "$NEW_MONITOR_INTERFACE" &> /dev/null; then
        MONITOR_INTERFACE="$NEW_MONITOR_INTERFACE"
        echo "✅ Interfaz monitor activada y detectada: $MONITOR_INTERFACE"
    else
        echo "❌ No se pudo activar el modo monitor o determinar la interfaz monitorizada."
        echo "Revisa la salida de airmon-ng start wlan0 para más detalles:"
        echo "$ACTIVATION_OUTPUT"
        exit 1
    fi

    # Espera un poco para que la interfaz se configure completamente
    sleep 2
    # Verifica una última vez que la interfaz monitor esté activa
    if ! ip link show "$MONITOR_INTERFACE" &> /dev/null; then
        echo "❌ $MONITOR_INTERFACE no está activa después de la activación. Saliendo."
        echo "Verifica si tienes una tarjeta Wi-Fi compatible y si ya está en modo monitor."
        exit 1
    fi
else
    echo "✅ $MONITOR_INTERFACE ya está activa."
fi

echo "✅ $MONITOR_INTERFACE está lista. Escaneando durante 15 segundos..."
echo ""
echo "--- ATENCIÓN: La terminal puede parecer en blanco durante el escaneo de airodump-ng. ---"
echo "--- Esto es normal. El script está recopilando datos en segundo plano. Por favor, espera. ---"
echo "--- No cierres la terminal ni presiones Ctrl+C hasta que el escaneo termine. ---"
echo ""

# Limpia cualquier archivo CSV o Kismet anterior para evitar confusiones antes de iniciar el escaneo
rm -f "${OUTPUT_PREFIX}-"*.csv "${OUTPUT_PREFIX}-"*.kismet.csv "${OUTPUT_PREFIX}-"*.kismet.netxml 2>/dev/null

# Ejecuta airodump-ng en segundo plano y captura su PID
sudo airodump-ng "$MONITOR_INTERFACE" --write "$OUTPUT_PREFIX" --output-format csv &
AERODUMP_PID=$! # Guarda el PID del proceso de airodump-ng

# Espera el tiempo de escaneo
sleep 15

# Termina el proceso de airodump-ng
echo "Finalizando escaneo de airodump-ng..."
sudo kill "$AERODUMP_PID" 2>/dev/null # Termina el proceso de airodump-ng
wait "$AERODUMP_PID" 2>/dev/null # Espera a que el proceso termine completamente

# Espera un segundo adicional para asegurar que airodump-ng termine de escribir el archivo
sleep 1

# Busca el archivo CSV generado. El nombre puede variar (ej. redes_detectadas-01.csv, -02.csv, etc.)
# Usamos 'find' para ser más robustos en la búsqueda del archivo más reciente.
# Ordenamos por tiempo de modificación y tomamos el más reciente.
GENERATED_CSV_FILE=$(find . -maxdepth 1 -name "${OUTPUT_PREFIX}-*.csv" -printf '%T@ %p\n' | sort -n | tail -1 | awk '{print $2}')

if [[ ! -f "$GENERATED_CSV_FILE" ]]; then
    echo "❌ No se generó el archivo de resultados CSV '${OUTPUT_PREFIX}-01.csv' (o similar)."
    echo "Posibles razones: No se detectaron redes Wi-Fi, problemas con la tarjeta, o airodump-ng no pudo escribir el archivo."
    echo "Asegúrate de que tu tarjeta esté en modo monitor y que haya redes Wi-Fi cerca para detectar."
    exit 1
fi

echo "✅ Archivo de resultados encontrado: $GENERATED_CSV_FILE"
echo "✅ Redes detectadas:"
echo "--------------------"
# Procesa el archivo CSV para mostrar las SSIDs, BSSIDs y canales
awk -F',' 'NR>1 && NF>13 && $1 !~ /BSSID/ {
    gsub(/^ +| +$/, "", $1); gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $14);
    if ($14 != "") {
        printf "📶 SSID: %s | BSSID: %s | Canal: %s\n", $14, $1, $4
    }
}' "$GENERATED_CSV_FILE"

echo "Script finalizado."
