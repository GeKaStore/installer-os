#!/bin/bash
# Skrip untuk menginstal layanan UDP Custom

source /usr/local/bin/ui.sh
clear

lane_atas
tengah "CONFIGURE UDP CUSTOM" "${BRED}${WHITE}" 1
lane_bawah

# --- PERBAIKAN: Definisikan path standar ---
BIN_PATH="/usr/local/bin/udp-custom"
CONF_DIR="/etc/udp-custom"
CONF_PATH="${CONF_DIR}/config.json"

# PERBAIKAN: Buat direktori konfigurasi di /etc, bukan /root
mkdir -p "$CONF_DIR"

# --- Unduh Binary ---
wget -q --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1ixz82G_ruRBnEEp4vLPNF2KZ1k8UfrkV' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1ixz82G_ruRBnEEp4vLPNF2KZ1k8UfrkV" -O "$BIN_PATH" && rm -rf /tmp/cookies.txt

# --- PERBAIKAN: Pengecekan Unduhan ---
if [ ! -s "$BIN_PATH" ]; then
    echo -e "${RED}FATAL: Gagal mengunduh 'udp-custom' binary. Instalasi dihentikan.${RESET}"
    exit 1
fi
chmod +x "$BIN_PATH"

# --- Unduh Konfigurasi ---
wget -q --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1_XNXsufQXzcTUVVKQoBeX5Ig0J7GngGM' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1_XNXsufQXzcTUVVKQoBeX5Ig0J7GngGM" -O "$CONF_PATH" && rm -rf /tmp/cookies.txt

# --- PERBAIKAN: Pengecekan Unduhan ---
if [ ! -s "$CONF_PATH" ]; then
    echo -e "${RED}FATAL: Gagal mengunduh 'config.json'. Instalasi dihentikan.${RESET}"
    rm -f "$BIN_PATH" # Hapus biner yang sudah terlanjur diunduh
    exit 1
fi
chmod 644 "$CONF_PATH"

# --- Buat Layanan Systemd ---
# PERBAIKAN: Hapus pengecekan '$1' (dead code) dan perbarui path
cat <<EOF > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target

[Service]
User=root
Type=simple
ExecStart=${BIN_PATH} server
WorkingDirectory=${CONF_DIR}
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF

# --- Mulai Layanan ---
systemctl daemon-reload
systemctl enable --now udp-custom

clear
rm -f "$0"
