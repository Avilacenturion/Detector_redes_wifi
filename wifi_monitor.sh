#!/bin/bash

echo "Iniciando escaneo de redes en modo monitor..."

# Verifica si wlan0mon está activa
if ! ip link show wlan0mon &> /dev/null; then
    echo "❌ wlan0mon no está activo. Actívalo con:"
    echo "   sudo airmon-ng start wlan0"
    exit 1
fi

# Ejecuta airodump-ng durante 15 segundos
echo "📡 Escaneando durante 15 segundos..."
timeout 15s airodump-ng wlan0mon --write redes_detectadas --output-format csv &> /dev/null

# Verifica que se haya generado el archivo
if [[ ! -f redes_detectadas-01.csv ]]; then
    echo "❌ No se generó el archivo de resultados."
    exit 1
fi

# Muestra los resultados
echo "✅ Redes detectadas:"
echo "--------------------"
awk -F',' 'NR>1 && NF>13 && $1 !~ /BSSID/ {
    gsub(/^ +| +$/, "", $1);  # BSSID
    gsub(/^ +| +$/, "", $4);  # Canal
    gsub(/^ +| +$/, "", $14); # SSID
    if ($14 != "") {
        printf "📶 SSID: %s | BSSID: %s | Canal: %s\n", $14, $1, $4
    }
}' redes_detectadas-01.csv

# Limpieza de archivos generados
rm -f redes_detectadas-01.csv redes_detectadas-01.kismet.csv redes_detectadas-01.kismet.netxml


