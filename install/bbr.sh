#!/bin.bash
# =========================================
# VERSI PERBAIKAN (Clean & Modern)
# - Menggunakan drop-in directories (.d)
# - Menghapus konflik IPv6
# - Jauh lebih cepat dan efisien
# =========================================

clear
source /usr/local/bin/ui.sh

# --- Fungsi 1: Instalasi BBR ---
# Tugas: Memuat modul kernel BBR dan memastikannya permanen.
Install_BBR() {
    lane_atas
    tengah "CONFIGURE TCP BBR" "${BRED}${WHITE}"
    lane_bawah
    
    # Cek apakah modul sudah dimuat
    if lsmod | grep -q "tcp_bbr"; then
        echo -e " ${GREEN}TCP BBR sudah aktif.${RESET}"
    else
        modprobe tcp_bbr
        
        # Cek ulang setelah modprobe
        if lsmod | grep -q "tcp_bbr"; then
            echo -e " ${GREEN}Modul TCP BBR berhasil dimuat.${RSET}"
        else
            echo -e " ${GREEN}Gagal memuat modul TCP BBR!${RESET}"
            return 1 # Keluar dari fungsi jika gagal
        fi
    fi
    
    # Pastikan modul dimuat saat boot
    # PERBAIKAN: Gunakan file .conf khusus, lebih bersih.
    echo "tcp_bbr" > /etc/modules-load.d/bbr.conf
    sleep 2
}

# --- Fungsi 2: Optimasi Parameter Sistem ---
# PERBAIKAN: Fungsi ini ditulis ulang total.
# Kita tidak lagi menggunakan 'grep' berulang-ulang.
# Kita menulis file konfigurasi baru ke direktori .d.
# Ini JAUH LEBIH CEPAT dan cara modern yang benar.

Optimize_Parameters() {
    clear
    lane_atas
    tengah "CONFIGURE OPTIMATION OF KERNEL PARAMETER" "${BRED}${WHITE}" 1
    lane_bawah

    # --- 2a. Optimasi sysctl (Network, Kernel, VM) ---
    # Semua parameter ini masuk ke satu file baru.
    cat > /etc/sysctl.d/99-wuzzstore-optimizations.conf << EOF
# --- Konfigurasi Optimasi oleh WuzzStore ---

# Pengaturan BBR (digabung ke sini)
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Pengaturan IPv4 Forwarding (diperlukan untuk routing/VPN)
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.route_localnet = 1

# Pengaturan IPv6 (Konsisten dengan Install.sh - NONAKTIFKAN)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
# PERBAIKAN: Semua tuning IPv6 lain dihapus karena tidak relevan jika dinonaktifkan

# Pengaturan Ukuran Buffer Memori
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 67108864
net.core.wmem_default = 67108864
net.core.optmem_max = 65536
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Pengaturan Koneksi (Limits)
fs.file-max = 51200
net.core.somaxconn = 10000
net.core.netdev_budget = 50000
net.core.netdev_budget_usecs = 5000
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 2000000
kernel.pid_max = 64000
vm.overcommit_memory = 1

# Pengaturan Conntrack (Penting untuk NAT/Firewall)
net.netfilter.nf_conntrack_max = 262144
net.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30

# Pengaturan Keamanan & Pengerasan Jaringan (Network Hardening)
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.all.arp_ignore = 2
net.ipv4.conf.default.arp_ignore = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2

# Pengaturan Performa TCP Lanjutan
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syncookies = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 2
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_frto = 0

# Pengaturan Garbage Collector (GC)
net.ipv4.neigh.default.gc_thresh1 = 2048
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv6.neigh.default.gc_thresh1 = 2048
net.ipv6.neigh.default.gc_thresh2 = 4096
net.ipv6.neigh.default.gc_thresh3 = 8192

# Pengaturan Swappiness
vm.swappiness = 1
#vm.nr_hugepages=1280
EOF

    # --- 2b. Optimasi Batas Keamanan (Limits) ---
    cat > /etc/security/limits.d/99-wuzzstore-optimizations.conf << EOF
# --- Konfigurasi Optimasi Batas oleh WuzzStore ---
* soft nofile 65535
* hard nofile 65535
root soft nofile 51200
root hard nofile 51200
EOF

    # --- 2c. Optimasi Systemd ---
    # Buat direktori .d jika belum ada
    mkdir -p /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/99-wuzzstore-optimizations.conf << EOF
# --- Konfigurasi Optimasi Systemd oleh WuzzStore ---
[Manager]
DefaultTimeoutStopSec=30s
DefaultLimitCORE=infinity
DefaultLimitNOFILE=65535
EOF
    
    echo -e "${GREEN}Optimasi parameter sistem selesai ditulis.${RESET}"
}

# --- Fungsi 3: Terapkan Perubahan ---
Apply_Changes() {
    # Terapkan perubahan sysctl
    echo "Menjalankan sysctl -p..."
    # PERBAIKAN: Terapkan HANYA file konfigurasi kita, atau semua.
    # sysctl -p /etc/sysctl.d/99-wuzzstore-optimizations.conf
    # Atau lebih baik, terapkan semua:
    sysctl -p
    if [ $? -ne 0 ]; then
        echo -e "${RED}Gagal menerapkan beberapa pengaturan sysctl.${RESET}"
    fi

    # Terapkan perubahan systemd
    systemctl daemon-reexec
}


# --- Alur Eksekusi Utama ---
Install_BBR
Optimize_Parameters
Apply_Changes # PERBAIKAN: Menambahkan fungsi ini agar perubahan langsung aktif

# PERBAIKAN: Menggunakan "$0" agar skrip bisa menghapus dirinya sendiri
# tidak peduli apa namanya atau di mana lokasinya.
rm -f "$0"
sleep 3
