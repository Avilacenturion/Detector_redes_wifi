#!/bin/bash

echo "Iniciando escaneo de redes en modo monitor..."

if ! ip link show wlan0mon &> /dev/null; then
    echo "❌ wlan0mon no está activo. Actívalo con:"
    echo "   sudo airmon-ng start wlan0"
    exit 1
fi

timeout 15s airodump-ng wlan0mon --write redes_detectadas --output-format csv &> /dev/null

echo "Redes detectadas:"
echo "-----------------"
awk -F',' '/^[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]+,[^,]*$/ && NR>1 {
    printf "📶 SSID: %s | BSSID: %s | Canal: %s\n", $14, $1, $4
}' redes_detectadas-01.csv

rm -f redes_detectadas-01.csv redes_detectadas-01.kismet.csv redes_detectadas-01.kismet.netxml

