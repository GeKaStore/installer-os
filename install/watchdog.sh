#!/bin/bash

# ==============================================================================
# Skrip Pemasangan & Konfigurasi Automatik Watchdog
# Versi: 1.1 (Dengan auto-load kernel module 'softdog')
#
# Skrip ini akan:
# 1. Memastikan ia dijalankan sebagai root.
# 2. Memasang pakej 'watchdog' untuk Debian/Ubuntu atau CentOS/RHEL.
# 3. Mengkonfigurasi '/etc/watchdog.conf' secara dinamik berdasarkan
#    spesifikasi sistem (CPU, RAM, Swap).
# 4. Memastikan modul kernel 'softdog' dimuatkan dan kekal selepas reboot.
# 5. Mengaktifkan dan memulakan servis 'watchdog'.
# ==============================================================================

# --- Fungsi Utama Pemasangan ---
install_watchdog() {
    # Fungsi ini direka untuk berjalan secara senyap (tiada output).
    # Sebarang ralat akan dihentikan dan fungsi akan kembalikan kod ralat.
    exec >/dev/null 2>&1

    # Langkah 1: Pasang pakej 'watchdog' berdasarkan OS
    if command -v apt-get; then
        apt-get update -y
        apt-get install -y watchdog
    elif command -v yum; then
        yum install -y watchdog
    else
        return 1 # Keluar jika tiada package manager ditemui
    fi
    
    # Pastikan pemasangan berjaya sebelum meneruskan
    if ! command -v watchdog; then
        return 1
    fi

    # Langkah 2: Dapatkan spesifikasi sistem
    CPU_CORES=$(nproc)
    PAGE_SIZE=$(getconf PAGESIZE)
    SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
    
    # Langkah 3: Kira nilai konfigurasi yang optimum
    MAX_LOAD_1=$((CPU_CORES * 5))
    MIN_MEM_PAGES=$((256 * 1024 * 1024 / PAGE_SIZE))
    MAX_SWAP_PAGES=$((SWAP_TOTAL_KB * 1024 * 3 / 4 / PAGE_SIZE))

    # Langkah 4: Tulis fail konfigurasi /etc/watchdog.conf
    tee /etc/watchdog.conf <<EOF
# Konfigurasi ini dijana secara automatik oleh skrip.
watchdog-device    = /dev/watchdog
interval           = 10
log-dir            = /var/log/watchdog
realtime           = yes
priority           = 1
max-load-1         = ${MAX_LOAD_1}
min-memory         = ${MIN_MEM_PAGES}
max-swap           = ${MAX_SWAP_PAGES}
EOF

    # Langkah 5: Pastikan kernel module 'softdog' dimuatkan & kekal
    modprobe softdog
    echo "softdog" | tee /etc/modules-load.d/watchdog.conf

    # Langkah 6: Aktifkan dan mulakan semula servis watchdog
    systemctl enable watchdog
    systemctl restart watchdog

    # Kembalikan output ke keadaan asal & kembalikan kod kejayaan (0)
    exec >/dev/tty 2>&1
    return 0
}

# --- Bahagian Utama Skrip (Pelaksanaan) ---

# Periksa jika skrip dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini perlu dijalankan sebagai root atau menggunakan 'sudo'." >&2
   exit 1
fi

echo "======================================================"
echo "   Memulakan Skrip Pemasangan Watchdog Automatik"
echo "======================================================"

echo -n "Memasang dan mengkonfigurasi watchdog... "
install_watchdog

# Periksa status kejayaan fungsi
if [ $? -eq 0 ]; then
    echo "[ BERJAYA ]"
    
    # Pengesahan terakhir: Periksa jika servis betul-betul aktif
    if systemctl is-active --quiet watchdog; then
        echo "PENGESAHAN: Servis watchdog kini 'active (running)'."
        echo "Setup selesai. VPS anda kini dipantau."
    else
        echo "AMARAN: Servis watchdog gagal untuk aktif. Sila semak dengan 'sudo systemctl status watchdog'."
    fi
else
    echo "[ GAGAL ]"
    echo "Sesuatu yang tidak dijangka telah berlaku semasa pemasangan."
    echo "Sila semak output ralat jika ada."
fi

echo "======================================================"

exit 0
