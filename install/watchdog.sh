#!/bin/bash
#
# SKRIP WATCHDOG & PENCATAT PENGGUNAAN
# Tugas: Memastikan layanan tetap berjalan dan mencatat penggunaan data bulanan.
# Dijalankan oleh: cron
#

# --- Bagian 1: Pengecekan Penggunaan Bandwidth (vnstat) ---

source /usr/local/bin/ui.sh
clear

lane_atas
tengah "CINFIGURE VNSTAT BANDWIDTH" "${BRED}${WHITE}" 1
lane_bawah

# Tentukan file sementara di /tmp (JANGAN di /etc)
TEMP_FILE="/tmp/vnstat_output.txt"
USAGE_FILE="/tmp/usage.txt"

# Dapatkan nama interface utama dari vnstat
IFACE_NAME=$(vnstat --iflist | awk 'NR==1 {print $1}')

if [ -z "$IFACE_NAME" ]; then
    echo -e "${RED}Error: Tidak dapat menemukan interface vnstat.${RESET}"
    exit 1
fi

# Simpan output vnstat ke file sementara
vnstat -i "$IFACE_NAME" > "$TEMP_FILE"

# Coba format 1: 'YYYY-MM' (contoh: 2025-11)
CURRENT_MONTH_Y_M=$(date +%Y-%m)
LINE_DATA=$(grep "$CURRENT_MONTH_Y_M " "$TEMP_FILE")

if [ -n "$LINE_DATA" ]; then
    # Format: 2025-11     87.52 GiB /  102.33 GiB / 189.85 GiB
    # Kolom 3+4 = TX (Upload), Kolom 6+7 = RX (Download)
    TX_VAL=$(echo "$LINE_DATA" | awk '{print $3 " " $4}')
    RX_VAL=$(echo "$LINE_DATA" | awk '{print $6 " " $7}')
else
    # Coba format 2: 'Mmm 'YY' (contoh: Nov '25)
    CURRENT_MONTH_B_Y=$(date +"%b '%y")
    LINE_DATA=$(grep "$CURRENT_MONTH_B_Y" "$TEMP_FILE")
    
    if [ -n "$LINE_DATA" ]; then
        # Format:  Nov '25    87.52 GiB / 102.33 GiB / 189.85 GiB
        # Kolom 3+4 = TX, Kolom 6+7 = RX
        TX_VAL=$(echo "$LINE_DATA" | awk '{print $3 " " $4}')
        RX_VAL=$(echo "$LINE_DATA" | awk '{print $6 " " $7}')
    else
        # Jika tidak ditemukan, set ke 0
        TX_VAL="0 B"
        RX_VAL="0 B"
    fi
fi

# Simpan ke /tmp/usage.txt
# Format: <Upload> / <Download>
echo "$TX_VAL / $RX_VAL" > "$USAGE_FILE"
rm -f "$TEMP_FILE" # Bersihkan file sementara

# --- Bagian 2: Watchdog Layanan ---

# Fungsi ini mengecek apakah layanan aktif. Jika tidak, aktifkan dan mulai.
function ensure_service_running() {
    local service_name="$1"
    
    # 'is-active --quiet' akan exit 0 jika aktif, non-zero jika tidak.
    if ! systemctl is-active --quiet "$service_name"; then
        echo -e "${CYAN}Watchdog: Layanan $service_name tidak aktif, memulai ulang...${RESET}"
        systemctl enable "$service_name" >/dev/null 2>&1
        systemctl start "$service_name"
    fi
}

# Daftar layanan yang perlu dicek
services_to_check=("xray" "haproxy" "nginx" "ws")

for srv in "${services_to_check[@]}"; do
    ensure_service_running "$srv"
done

# Pengecekan khusus untuk 'kyt'
if [[ -e /usr/bin/kyt ]]; then
    ensure_service_running "kyt"
fi

# --- Bagian 3: Instalasi & Watchdog apisellvpn ---
# Bagian ini akan menginstal layanan jika file .service-nya tidak ada

SERVICE_PATH="/etc/systemd/system/apisellvpn.service"
if [[ -f "$SERVICE_PATH" ]]; then
    # Jika file ada, cukup pastikan layanan berjalan
    ensure_service_running "apisellvpn"
else
    # Jika file tidak ada, jalankan instalasi
    echo -e "${CYAN}Watchdog: Service apisellvpn belum ada, menginstal...${RESET}"
    
    # Masuk ke direktori /tmp untuk mengunduh
    cd /tmp
    wget -q https://raw.githubusercontent.com/Diah082/Vip/main/install/apiserver -O apiserver
    chmod +x apiserver
    ./apiserver apisellvpn
    rm -f apiserver # Bersihkan file installer
    cd # Kembali ke direktori sebelumnya (atau home)
fi

# --- Bagian 4: HAPUS ---
# PERBAIKAN: Perintah 'pkill bash' yang berbahaya DIHAPUS.

# --- Bagian 5: HAPUS ---
# PERBAIKAN: Panggilan ke 'install/autocpu.sh' DIHAPUS.

clear
rm -f "$0"
