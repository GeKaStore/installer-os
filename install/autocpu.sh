#!/bin/bash
#
# SKRIP WATCHDOG & PENCATAT PENGGUNAAN
# Tugas: Memastikan layanan tetap berjalan dan mencatat penggunaan data bulanan.
# Dijalankan oleh: cron
#

# --- Bagian 1: Pengecekan Penggunaan Bandwidth (vnstat) ---
# PERBAIKAN: Logika vnstat ditulis ulang sepenuhnya agar berfungsi.

echo "Mengecek penggunaan bandwidth vnstat..."

# Tentukan file sementara di /tmp
TEMP_FILE="/tmp/vnstat_output.txt"
USAGE_FILE="/tmp/usage.txt"

# Dapatkan nama interface utama dari vnstat
IFACE_NAME=$(vnstat --iflist | awk 'NR==1 {print $1}')

if [ -z "$IFACE_NAME" ]; then
    echo "Error: Tidak dapat menemukan interface vnstat." >&2
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

# PERBAIKAN: Simpan ke /tmp/usage.txt (bukan /etc/usage2)
# Format: <Upload> / <Download>
echo "$TX_VAL / $RX_VAL" > "$USAGE_FILE"
rm -f "$TEMP_FILE" # Bersihkan file sementara

# --- Bagian 2: Watchdog Layanan ---
# PERBAIKAN: Menggunakan satu fungsi untuk semua layanan (Jauh lebih singkat)

echo "Memeriksa status layanan..."

# Fungsi ini mengecek apakah layanan aktif. Jika tidak, aktifkan dan mulai.
function ensure_service_running() {
    local service_name="$1"
    
    # 'is-active --quiet' akan exit 0 jika aktif, non-zero jika tidak.
    if ! systemctl is-active --quiet "$service_name"; then
        echo "Watchdog: Layanan $service_name tidak aktif, memulai ulang..."
        # Gunakan 'enable --now' untuk mengaktifkan dan memulai dalam satu perintah
        # Atau gunakan dua perintah agar konsisten dengan Install.sh
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
    echo "Watchdog: Service apisellvpn belum ada, menginstal..."
    
    # Masuk ke direktori /tmp untuk mengunduh
    cd /tmp
    wget -q https://raw.githubusercontent.com/Diah082/Vip/main/install/apiserver -O apiserver
    chmod +x apiserver
    ./apiserver apisellvpn
    rm -f apiserver # Bersihkan file installer
    cd # Kembali ke direktori sebelumnya (atau home)
fi

# --- Bagian 4: Proteksi Fork Bomb (SANGAT BERBAHAYA) ---
# PERBAIKAN: Perintah 'pkill bash' DIHAPUS.
# Alasan: Perintah ini sangat berbahaya dan dapat mematikan
# sesi SSH pengguna lain, skrip cron penting, dan merusak sistem.
# Jangan pernah gunakan 'pkill bash' dalam skrip otomatis.

# bash2=$( pgrep bash | wc -l )
# if [[ $bash2 -gt "20" ]]; then
# pkill bash
# fi

# --- Bagian 5: Panggil skrip autocpu.sh ---
# PERBAIKAN: Path diasumsikan relatif terhadap PWD (Current Working Directory)
# dari tempat cronjob ini dijalankan. Perintah 'cd' yang aneh telah dihapus.
echo "Menjalankan autocpu.sh..."
install/autocpu.sh
