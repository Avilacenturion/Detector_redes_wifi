#!/bin/bash

echo "Iniciando escaneo de redes en modo monitor..."

# Verifica si wlan0mon está activa
if ! ip link show wlan0mon &> /dev/null; then
    echo "⚠️ wlan0mon no está activa. Intentando activarla..."

    # Intenta matar procesos que interfieren
    sudo airmon-ng check kill
    sudo airmon-ng start wlan0

    # Espera un poco y verifica otra vez
    sleep 2
    if ! ip link show wlan0mon &> /dev/null; then
        echo "❌ No se pudo activar wlan0mon. Verifica si tienes una tarjeta compatible."
        exit 1
    fi
fi

echo "✅ wlan0mon está activa. Escaneando durante 15 segundos..."

# *** CAMBIO AQUÍ: Se eliminó '&> /dev/null' para ver la salida de airodump-ng ***
timeout 15s airodump-ng wlan0mon --write redes_detectadas --output-format csv

# Espera un momento para asegurar que airodump-ng termine de escribir
sleep 1

if [[ ! -f redes_detectadas-01.csv ]]; then
    echo "❌ No se generó el archivo de resultados 'redes_detectadas-01.csv'."
    echo "Revisa la salida de airodump-ng para posibles errores."
    exit 1
fi

echo "✅ Redes detectadas:"
echo "--------------------"
awk -F',' 'NR>1 && NF>13 && $1 !~ /BSSID/ {
    gsub(/^ +| +$/, "", $1); gsub(/^ +| +$/, "", $4); gsub(/^ +| +$/, "", $14);
    if ($14 != "") {
        printf "📶 SSID: %s | BSSID: %s | Canal: %s\n", $14, $1, $4
    }
}' redes_detectadas-01.csv

# Limpieza
rm -f redes_detectadas-01.csv redes_detectadas-01.kismet.csv redes_detectadas-01.kismet.netxml 2>/dev/null

# Limpieza de archivos generados
rm -f redes_detectadas-01.csv redes_detectadas-01.kismet.csv redes_detectadas-01.kismet.netxml


