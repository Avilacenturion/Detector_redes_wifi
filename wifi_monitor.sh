#!/bin/bash

echo "Iniciando escaneo de redes en modo monitor..."

# --- IMPORTANTE: Este script requiere permisos de root. Por favor, ejecútalo con: sudo ./wifi_monitor.sh ---

# Verifica si wlan0mon está activa. Si no, intenta activarla.
if ! ip link show wlan0mon &> /dev/null; then
    echo "⚠️ wlan0mon no está activa. Intentando activarla..."

    # Intenta matar procesos que interfieren con el modo monitor
    echo "Ejecutando: sudo airmon-ng check kill"
    # El '|| { ...; exit 1; }' asegura que el script se detenga si este comando falla.
    sudo airmon-ng check kill || { echo "❌ Error al ejecutar airmon-ng check kill. Asegúrate de tener permisos de root y de que airmon-ng esté instalado."; exit 1; }
    
    echo "Ejecutando: sudo airmon-ng start wlan0"
    # Captura la salida de airmon-ng start para identificar la interfaz monitorizada.
    # A veces no es 'wlan0mon', puede ser 'wlan1mon' u otra.
    MONITOR_INTERFACE=$(sudo airmon-ng start wlan0 | grep "monitor mode enabled" | awk '{print $NF}')
    
    # Verifica si se pudo determinar la interfaz monitorizada
    if [ -z "$MONITOR_INTERFACE" ]; then
        echo "❌ No se pudo determinar la interfaz en modo monitor automáticamente."
        # Intenta una verificación manual si 'wlan0mon' existe después de la activación
        if ip link show wlan0mon &> /dev/null; then
            MONITOR_INTERFACE="wlan0mon"
            echo "✅ Se detectó 'wlan0mon' después de intentar activar el modo monitor."
        else
            echo "❌ Fallo al activar el modo monitor o al encontrar la interfaz. Saliendo."
            exit 1
        fi
    fi
    
    echo "✅ Interfaz monitor detectada: $MONITOR_INTERFACE"

    # Espera un poco para que la interfaz se configure completamente
    sleep 2
    # Verifica una última vez que la interfaz monitor esté activa
    if ! ip link show "$MONITOR_INTERFACE" &> /dev/null; then
        echo "❌ No se pudo activar $MONITOR_INTERFACE. Verifica si tienes una tarjeta Wi-Fi compatible o si ya está en modo monitor."
        exit 1
    fi
else
    MONITOR_INTERFACE="wlan0mon" # Si ya estaba activa, asumimos que es wlan0mon
    echo "✅ $MONITOR_INTERFACE ya está activa."
fi

echo "✅ $MONITOR_INTERFACE está lista. Escaneando durante 15 segundos..."
echo ""
echo "--- ATENCIÓN: La terminal puede parecer en blanco durante el escaneo de airodump-ng. ---"
echo "--- Esto es normal. El script está recopilando datos en segundo plano. Por favor, espera. ---"
echo ""

# Limpia cualquier archivo CSV o Kismet anterior para evitar confusiones
rm -f redes_detectadas-*.csv redes_detectadas-*.kismet.csv redes_detectadas-*.kismet.netxml 2>/dev/null

# Ejecuta airodump-ng con un tiempo límite. La salida interactiva puede no mostrarse.
# Esto es intencional para que el script sea autónomo.
timeout 15s airodump-ng "$MONITOR_INTERFACE" --write redes_detectadas --output-format csv

# Espera un segundo adicional para asegurar que airodump-ng termine de escribir el archivo
sleep 1

# Busca el archivo CSV generado. El nombre puede variar (ej. redes_detectadas-01.csv, -02.csv, etc.)
# Usamos 'find' para ser más robustos en la búsqueda del archivo más reciente.
CSV_FILE=$(find . -maxdepth 1 -name "redes_detectadas-*.csv" -print -quit)

if [[ ! -f "$CSV_FILE" ]]; then
    echo "❌ No se generó el archivo de resultados CSV."
    echo "Posibles razones: No se detectaron redes Wi-Fi, problemas con la tarjeta, o airodump-ng no pudo escribir el archivo."
    echo "Asegúrate de que tu tarjeta esté en modo monitor y que haya redes Wi-Fi cerca para detectar."
    exit 1
fi

echo "✅ Archivo de resultados encontrado: $CSV_FILE"
echo "✅ Redes detectadas:"
echo "--------------------"
# Procesa el archivo CSV para mostrar las SSIDs, BSSIDs y canales
awk -F',' 'NR>1 && NF>13 && $1 !~ /BSSID/ {
    gsub(/^ +| +$/, "", $1); gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $14);
    if ($14 != "") {
        printf "📶 SSID: %s | BSSID: %s | Canal: %s\n", $14, $1, $4
    }
}' "$CSV_FILE"

# Realiza la limpieza de los archivos temporales generados por airodump-ng
echo "Realizando limpieza de archivos temporales..."
rm -f redes_detectadas-*.csv redes_detectadas-*.kismet.csv redes_detectadas-*.kismet.netxml 2>/dev/null

echo "Script finalizado."
