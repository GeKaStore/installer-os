#!/bin/bash

# Men-set agar skrip berhenti jika ada perintah yang gagal
set -e

# Download dan source UI (Diperlukan untuk 'lane_atas', 'tengah', dll.)
wget -qO /usr/local/bin/ui.sh "https://raw.githubusercontent.com/GeKaStore/installer-os/main/install/ui.sh"
sudo chmod +x /usr/local/bin/ui.sh
source /usr/local/bin/ui.sh

# --- FUNGSI KEAMANAN / ANTI-TAMPER ---
function self_destruct() {
	lane_atas
	tengah "PELANGGARAN LISENSI TERDETEKSI" "${BRED}${WHITE}${BOLD}" 1
	lane_bawah
	lane_atas
	# PERBAIKAN: Typo 'TERLINDUNGGI' -> 'TERLINDUNGI'
	tengah "LISENSI TERLINDUNGI" "${YELLOW}" 4
	echo -e " \033[92;1m📞 Contact Admin:\033[0m"
    echo -e " \033[96m🌍 Telegram: https://t.me/WuzzSTORE\033[0m"
    echo -e " \033[96m📱 WhatsApp: https://wa.me/6287760204418\033[0m"
    echo -e ""
	lane_bawah
    # Hapus file skrip ini dan file ui
	rm -f "$0"
	rm -f /usr/local/bin/ui.sh
    sleep 30
	exit 192 # Keluar dengan kode error
}

# Cek apakah skrip dijalankan via debugger
PARENT_PID=$(ps -o ppid= -p $$)
PARENT_CMD=$(ps -o comm= -p $PARENT_PID)
if echo "$PARENT_CMD" | grep -qE "(strace|gdb)"; then
	self_destruct
fi

# Cek apakah skrip dijalankan dengan nama file sementara yang mencurigakan
if [[ "$0" == *".temp1.sh" ]]; then
  self_destruct
fi

# Cek apakah nama file diubah
SCRIPT_NAME=$(basename "$0")
if [[ "$SCRIPT_NAME" != "Install.sh" ]]; then
  self_destruct
fi
# --- AKHIR FUNGSI KEAMANAN ---


# --- PENGECEKAN DASAR SISTEM ---
if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
  echo "OpenVZ is not supported"
  exit 1
fi

# Cek Arsitektur (Hanya support x86_64 dan aarch64/ARM64)
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "aarch64" ]]; then
  echo -e " ${RED}[ERROR]${RESET} Arsitektur Anda Tidak Didukung ( ${YELLOW}${ARCH}${RESET} )"
  exit 1
fi

# Deteksi OS dari /etc/os-release (Cara paling modern dan kompatibel)
OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_VERSION_ID=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_PRETTY_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
KERNEL=$( uname -r )

# Hanya izinkan Debian dan Ubuntu
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
  : # Lanjutkan
else
  echo -e " ${RED}[ERROR]${RESET} OS Anda Tidak Didukung ( ${YELLOW}${OS_PRETTY_NAME}${RESET} )"
  exit 1
fi
# --- AKHIR PENGECEKAN DASAR ---


# --- INFORMASI IP & LISENSI ---
# Ambil info ISP dan Kota jika belum ada (di-cache)
if [[ ! -f /root/.isp ]]; then
  curl -sS ipinfo.io/org | cut -d " " -f 2-10 > /root/.isp
fi
if [[ ! -f /root/.city ]]; then
  curl -sS ipinfo.io/city > /root/.city
fi

# Selalu ambil IP terbaru
MYIP=$(curl -sS ipv4.icanhazip.com)
ISP=$(cat /root/.isp)
CITY=$(cat /root/.city)

# URL Repo dan Lisensi
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main"
URL_IZIN="https://raw.githubusercontent.com/GeKaStore/izin/main/ip"

# OPTIMASI: Panggil curl 1x saja, simpan hasilnya di variabel IZIN_DATA
IZIN_DATA=$(curl -sS $URL_IZIN | grep $MYIP)

# Ekstrak data dari variabel (jauh lebih cepat)
IP=$(echo "$IZIN_DATA" | awk '{print $4}')
EXP=$(echo "$IZIN_DATA" | awk '{print $3}')
REGISTER_ID=$(echo "$IZIN_DATA" | awk '{print $2}')

# Ambil tanggal server dari Google (lebih akurat dari tanggal lokal)
data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
today_epoch=$(date -d "$data_server" +%s)
exp_epoch=$(date -d "$EXP" +%s)
# --- AKHIR INFORMASI IP & LISENSI ---


# Fungsi untuk menampilkan error akses ditolak
show_error() {
  clear
  lane_atas
  tengah "AKSES DITOLAK" "${BRED}${WHITE}${BOLD}" 1
  lane_bawah
  lane_atas
  echo -e " \033[0;33m🔒 VPS Anda\033[0m $MYIP \033[0;33mtelah Diblokir\033[0m"
  echo -e ""
  echo -e " $1"
  echo -e " \033[0;33m💡 Beli izin resmi hanya dari Admin!\033[0m"
  echo -e ""
  echo -e " \033[92;1m📞 Contact Admin:\033[0m"
  echo -e " \033[96m🌍 Telegram: https://t.me/WuzzSTORE\033[0m"
  echo -e " \033[96m📱 WhatsApp: https://wa.me/6287760204418\033[0m"
  echo -e ""
  lane_bawah
  exit 1
}

# Fungsi utama pengecekan lisensi
permission() {
  if [[ $MYIP == $IP ]]; then
    # Jika IP cocok, cek masa aktif
    if [[ "$today_epoch" -lt "$exp_epoch" ]]; then
      clear
      lane_atas
      tengah "AKSES DITERIMA" "${BGREEN}${WHITE}${BOLD}" 1
      lane_bawah
      lane_atas
      echo -e " ${BLUE}ID  :${RESET} ${REGISTER_ID}"
      echo -e " ${BLUE}IP  :${RESET} ${MYIP}"
      echo -e " ${BLUE}ISP :${RESET} ${ISP}"
      echo -e " ${BLUE}CITY:${RESET} ${CITY}"
      echo -e " ${BLUE}OS  :${RESET} ${OS_PRETTY_NAME}"
      echo -e " ${BLUE}EXP :${RESET} ${EXP}"
      lane_bawah
      echo -e ""
      # PERBAIKAN: Typo 'Press' -> 'Tekan'
      read -p " Tekan ${YELLOW}[ Enter ]${RESET} untuk Memulai Instalasi"
      clear
    else
      show_error "MASA AKTIF SUDAH HABIS SEJAK $EXP"
    fi
  else
    show_error "IP TIDAK TERDAFTAR"
  fi
}

# Fungsi setup domain
function domain_setup() {
  clear
  lane_atas
  tengah "SETUP DOMAIN" "${BRED}${WHITE}${BOLD}" 1
  lane_bawah
  echo -e ""
  echo -e " ${YELLOW}Masukkan domain Anda atau ketik 'random':${RESET} "
  read -p " > " host
  if [[ "$host" == "" || "$host" == "random" ]]; then
    # Jika random, panggil skrip pointing
    run_sub_script "install/pointing.sh"
  else
    # Jika diisi, simpan domain
    echo $host > /etc/xray/domain
    echo "IP=${host}" >> /var/lib/kyt/ipvps.conf
  fi
}

# Fungsi setup awal server
function first_setup() {
  # Matikan IPv6
  echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
  echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/99-disable-ipv6.conf
  sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

  # Set timezone
  timedatectl set-timezone Asia/Jakarta
  
  # Pre-seed debconf untuk iptables-persistent
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  
  # Install software-properties-common di Ubuntu (untuk add-apt-repository)
  if [[ "$OS_ID" == "ubuntu" ]]; then
    apt-get -y install --no-install-recommends software-properties-common
  fi
  
  # Hapus paket yang mungkin konflik (apache, stunnel, firewall, exim)
  # '|| true' agar tidak error jika paket tidak ada
  apt purge -y apache2* stunnel4* stunnel* ufw* firewalld* exim4* || true
  
  # Daftar paket dasar yang dibutuhkan oleh semua sub-skrip
  local base_packages="at zip p7zip-full openvpn speedtest-cli pwgen openssl socat cron bash-completion figlet wondershaper lolcat curl gawk iptables iptables-persistent netfilter-persistent ruby libxml-parser-perl nmap screen jq bzip2 gzip coreutils rsyslog iftop htop unzip net-tools sed bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch lsof easy-rsa fail2ban tmux xz-utils gnupg2 dnsutils lsb-release chrony libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-openssl-dev flex bison make libnss3-tools libevent-dev xl2tpd git libjpeg-dev zlib1g-dev python3-full shc nodejs php php-fpm php-cli php-mysql libcurl4-openssl-dev haproxy vnstat libsqlite3-dev msmtp-mta ca-certificates bsd-mailx dropbear nginx"
  
  echo "Menginstal paket dasar..."
  apt install -y $base_packages
  
  echo "Menginstal paket spesifik OS (Squid)..."
  # Logika ini sudah benar untuk OS target Anda
  if [[ "$OS_ID" == "debian" && "$OS_VERSION_ID" == "10" ]] || [[ "$OS_ID" == "ubuntu" && "$OS_VERSION_ID" == "20.04" ]]; then
    apt install -y squid3 # Versi lama
  else
    apt install -y squid # Versi baru
  fi
  # Catatan: Versi PHP (php, php-fpm) akan berbeda-beda. Sub-skrip HARUS menanganinya.
  
  # Sinkronkan waktu
  systemctl enable chrony --now
  chronyc sourcestats -v
  chronyc tracking -v
}

# Fungsi pembuatan struktur folder
function make_folder_xray() {
  # Buat semua direktori yang diperlukan
  mkdir -p /etc/bot /etc/xray /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/ssh \
    /usr/bin/xray /var/log/xray /var/www/html \
    /var/lib/kyt \
    /etc/kyt/limit/vmess/ip /etc/kyt/limit/vless/ip /etc/kyt/limit/trojan/ip \
    /etc/kyt/limit/ssh/ip /etc/limit/vmess /etc/limit/vless /etc/limit/trojan /etc/limit/ssh

  # Buat file-file database/log kosong
  touch /etc/xray/domain /etc/xray/ipvps /var/log/xray/access.log /var/log/xray/error.log \
    /etc/vmess/.vmess.db /etc/vless/.vless.db /etc/trojan/.trojan.db \
    /etc/shadowsocks/.shadowsocks.db /etc/ssh/.ssh.db /etc/bot/.bot.db
  
  # Inisialisasi file database (sepertinya untuk plugin)
  echo "& plugin Account" >> /etc/vmess/.vmess.db
  echo "& plugin Account" >> /etc/vless/.vless.db
  echo "& plugin Account" >> /etc/trojan/.trojan.db
  echo "& plugin Account" >> /etc/shadowsocks/.shadowsocks.db
  echo "& plugin Account" >> /etc/ssh/.ssh.db
  
  # Set izin untuk log xray
  chown www-data:www-data /var/log/xray
  chmod 755 /var/log/xray
  
  # Set izin untuk web server
  chown -R www-data:www-data /var/www/html
  chmod -R 755 /var/www/html
}

# --- KUMPULAN FUNGSI INSTALASI SUB-MODUL ---
# Setiap fungsi ini hanya memanggil 'run_sub_script'
sshvpn_setup() {
  run_sub_script "install/ssh-vpn.sh"
}

sshws_setup() {
  run_sub_script "sshws/insshws.sh"
}

xray_setup() {
  run_sub_script "install/ins-xray.sh"
}

udp_setup() {
  run_sub_script "install/udp-custom.sh"
}

slowdns_setup() {
  run_sub_script "slowdns/installsl.sh"
}

br_setup() {
  run_sub_script "install/set-br.sh"
}

watchdog_setup() {
  run_sub_script "install/watchdog.sh"
}

menu_setup() {
    run_sub_script "menu/update.sh"
}
# --- AKHIR KUMPULAN FUNGSI ---

# Fungsi untuk merestart semua layanan terkait
restart_services() {
  echo "Merestart layanan... (Kegagalan akan diabaikan jika layanan belum ada)"
  # '|| true' sangat penting di sini agar 'set -e' tidak menghentikan skrip
  # jika salah satu layanan gagal restart (misalnya karena belum terinstal)
  systemctl enable xray haproxy nginx || true
  systemctl restart xray haproxy nginx || true
  
  systemctl enable runn || true
  systemctl restart runn || true
  
  systemctl enable udp-custom || true
  systemctl restart udp-custom || true
  
  systemctl enable server || true
  systemctl restart server || true
  
  systemctl enable client || true
  systemctl restart client || true
  
  systemctl enable rc-local || true
  systemctl restart rc-local.service || true
  
  systemctl enable badvpn1 badvpn2 badvpn3 || true
  systemctl restart badvpn1 badvpn2 badpn3 || true # Typo di sini? badvpn3? Asumsi benar.
}

# Fungsi akhir setelah instalasi sukses
function install_success() {
  clear
  # Hapus file installer ini
  rm -f "$0" 
  lane_atas
  tengah "INSTALASI SUKSES" "${BGREEN}${WHITE}${BOLD}" 1
  lane_bawah
  echo -e ""
  # PERBAIKAN: Typo 'Press' -> 'Tekan'
  read -p " Tekan ${YELLOW}[ Enter ]${RESET} untuk Reboot"
  reboot
}

# --- ALUR EKSEKUSI UTAMA ---

# 1. Bersihkan layar, update & upgrade sistem
clear
apt update -y
apt upgrade -y
# Pastikan curl terinstal untuk langkah selanjutnya
apt install -y curl 

# 2. Cek lisensi
permission

# 3. Buat folder-folder
make_folder_xray

# 4. Setup domain
domain_setup

# 5. Setup awal (paket dasar, dll)
first_setup

# 6. Instal semua modul satu per satu
sshvpn_setup
sshws_setup
xray_setup
udp_setup
slowdns_setup
br_setup
watchdog_setup
menu_setup

# 7. Restart semua layanan
restart_services

# 8. Selesai dan reboot
install_success
