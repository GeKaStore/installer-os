#!/bin/bash

set -e

wget -qO /usr/local/bin/ui.sh "https://raw.githubusercontent.com/GeKaStore/installer-os/main/install/ui.sh"
sudo chmod +x /usr/local/bin/ui.sh

source /usr/local/bin/ui.sh

# KEAMANAN
function self_destruct() {
	lane_atas
	tengah "PELANGGARAN LISENSI TERDETEKSI" "${BRED}${WHITE}${BOLD}" 1
	lane_bawah
	lane_atas
	tengah "LISENSI TERLINDUNGGI" "${YELLOW}" 4
	echo -e " \033[92;1m📞 Contact Admin:\033[0m"
  echo -e " \033[96m🌍 Telegram: https://t.me/WuzzSTORE\033[0m"
  echo -e " \033[96m📱 WhatsApp: https://wa.me/6287760204418\033[0m"
  echo -e ""
	lane_bawah
	rm -rf "$0"
	rm -rf /usr/local/bin/ui.sh
  sleep 30
	exit 192
}
PARENT_PID=$(ps -o ppid= -p $$)
PARENT_CMD=$(ps -o comm= -p $PARENT_PID)
SCRIPT_NAME=$(basename "$0")
if echo "$PARENT_CMD" | grep -qE "(strace|gdb)"; then
	self_destruct
fi
if [[ "$0" == *".temp1.sh" ]]; then
  self_destruct
fi
if [[ "$SCRIPT_NAME" != "Install.sh" ]]; then
  self_destruct
fi

# --- KREDENSIAL DIHAPUS ---
# (Sengaja dikosongkan untuk keamanan)

if [ "${EUID}" -ne 0 ]; then
  echo "You need to run this script as root"
  exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
  echo "OpenVZ is not supported"
  exit 1
fi
if [[ $( uname -m | awk '{print $1}' ) == "x86_64" ]]; then
  :
else
  echo -e " ${RED}[ERROR]${RESET} Your Architecture is Not Supported ( ${YELLOW}$(uname -m)${RESET} )"
  exit 1
fi

OS_ID=$(grep '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
OS_NAME=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
KERNEL=$( uname -r )
ARCH=$( uname -m )
if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
  :
else
  echo -e " ${RED}[ERROR]${RESET} OS Anda Tidak Didukung ( ${YELLOW}${OS_NAME}${RESET} )"
  exit 1
fi

if [[ ! -f /root/.isp ]]; then
  curl -sS ipinfo.io/org | cut -d " " -f 2-10 > /root/.isp
fi
if [[ ! -f /root/.city ]]; then
  curl -sS ipinfo.io/city > /root/.city
fi

MYIP=$(curl -sS ipv4.icanhazip.com)
ISP=$(cat /root/.isp)
CITY=$(cat /root/.city)

REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main"
URL_IZIN="https://raw.githubusercontent.com/GeKaStore/izin/main/ip"
IP=$(curl -sS $URL_IZIN | grep $MYIP | awk '{print $4}')
EXP=$(curl -sS $URL_IZIN | grep $MYIP | awk '{print $3}')
REGISTER_ID=$(curl -sS $URL_IZIN | grep $MYIP | awk '{print $2}')

data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
date_list=$(date +"%Y-%m-%d" -d "$data_server")
today=`date -d "0 days" +"%Y-%m-%d"`
time=$(printf '%(%H:%M:%S)T')
date=$(date +'%d-%m-%Y')
d1=$(date -d "$exp" +%s)
d2=$(date -d "$today" +%s)
certifacate=$(((d1 - d2) / 86400))

show_error() {
  clear
  lane_atas
  tengah "AKSES DITOLAK" "${BRED}${WHITE}${BOLD}" 1
  lane_bawah
  lane_atas
  echo -e " \033[0;33m🔒 Your VPS\033[0m $MYIP \033[0;33mHas been Banned\033[0m"
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

permission() {
  if [[ $MYIP == $IP ]]; then
    if [[ $date_list < $EXP ]]; then
      clear
      lane_atas
      tengah "AKSES DITERIMA" "${BGREEN}${WHITE}${BOLD}" 1
      lane_bawah
      lane_atas
      echo -e " ${BLUE}ID  :${RESET} ${REGISTER_ID}"
      echo -e " ${BLUE}IP  :${RESET} ${MYIP}"
      echo -e " ${BLUE}ISP :${RESET} ${ISP}"
      echo -e " ${BLUE}CITY:${RESET} ${CITY}"
      echo -e " ${BLUE}OS  :${RESET} ${OS_NAME}"
      echo -e " ${BLUE}EXP :${RESET} ${EXP}"
      lane_bawah
      echo -e ""
      read -p "Press ${YELLOW}[ Enter ]${RESET} to Install"
      clear
    else
      show_error "MASA AKTIF SUDAH HABIS SEJAK $EXP"
    fi
  else
    show_error "IP TIDAK TERDAFTAR"
  fi
}

function domain_setup() {
  clear
  lane_atas
  tengah "SETUP DOMAIN" "${BRED}${WHITE}${BOLD}" 1
  lane_bawah
  echo -e ""
  echo -e " ${YELLOW}Masukkan domain anda atau ketik random:${RESET} "
  read -p " > " host
  if [[ "$host" == "" || "$host" == "random" ]]; then
    bash <(wget -qO- ${REPO}/install/pointing.sh)
  else
    echo $host > /etc/xray/domain
    echo "IP=${host}" >> /var/lib/kyt/ipvps.conf
  fi
}

function first_setup() {
  echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
  echo "net.ipv6.conf.all.disable_ipv6 = 1" > /etc/sysctl.d/99-disable-ipv6.conf
  sysctl -p /etc/sysctl.d/99-disable-ipv6.conf

  timedatectl set-timezone Asia/Jakarta
  
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
  
  if [[ "$OS_ID" == "ubuntu" ]]; then
    apt-get -y install --no-install-recommends software-properties-common
  fi
  
  apt purge -y apache2* stunnel4* stunnel* ufw* firewalld* exim4* >/dev/null 2>&1
  
  apt install -y at zip p7zip-full openvpn speedtest-cli pwgen openssl socat cron bash-completion figlet wondershaper lolcat curl gawk iptables iptables-persistent netfilter-persistent ruby libxml-parser-perl squid nmap screen jq bzip2 gzip coreutils rsyslog iftop htop unzip net-tools sed bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch lsof easy-rsa fail2ban tmux xz-utils gnupg2 dnsutils lsb-release chrony libnss3-dev libnspr4-dev pkg-config libpam0g-dev libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-openssl-dev flex bison make libnss3-tools libevent-dev xl2tpd git libjpeg-dev zlib1g-dev python3-full shc nodejs php php-fpm php-cli php-mysql libcurl4-openssl-dev haproxy vnstat libsqlite3-dev msmtp-mta ca-certificates bsd-mailx dropbear nginx
  
  systemctl enable chrony --now
  chronyc sourcestats -v
  chronyc tracking -v
}

function make_folder_xray() {
  mkdir -p /etc/bot /etc/xray /etc/vmess /etc/vless /etc/trojan /etc/shadowsocks /etc/ssh \
    /usr/bin/xray /var/log/xray /var/www/html \
    /var/lib/kyt \
    /etc/kyt/limit/vmess/ip /etc/kyt/limit/vless/ip /etc/kyt/limit/trojan/ip \
    /etc/kyt/limit/ssh/ip /etc/limit/vmess /etc/limit/vless /etc/limit/trojan /etc/limit/ssh

  touch /etc/xray/domain /etc/xray/ipvps /var/log/xray/access.log /var/log/xray/error.log \
    /etc/vmess/.vmess.db /etc/vless/.vless.db /etc/trojan/.trojan.db \
    /etc/shadowsocks/.shadowsocks.db /etc/ssh/.ssh.db /etc/bot/.bot.db
  
  echo "& plugin Account" >> /etc/vmess/.vmess.db
  echo "& plugin Account" >> /etc/vless/.vless.db
  echo "& plugin Account" >> /etc/trojan/.trojan.db
  echo "& plugin Account" >> /etc/shadowsocks/.shadowsocks.db
  echo "& plugin Account" >> /etc/ssh/.ssh.db
  
  chown www-data:www-data /var/log/xray
  chmod 755 /var/log/xray
  
  chown -R www-data:www-data /var/www/html
  chmod -R 755 /var/www/html
}

sshvpn_setup() {
  bash <(wget -qO- ${REPO}/install/ssh-vpn.sh)
}

sshws_setup() {
  bash <(wget -qO- ${REPO}/sshws/insshws.sh)
}

xray_setup() {
  bash <(wget -qO- ${REPO}/install/ins-xray.sh)
}

udp_setup() {
  bash <(wget -qO- ${REPO}/install/udp-custom.sh)
}

slowdns_setup() {
  bash <(wget -qO- ${REPO}/slowdns/installsl.sh)
}

br_setup() {
  bash <(wget -qO- ${REPO}/install/set-br.sh)
}

watchdog_setup() {
  bash <(wget -qO- ${REPO}/install/watchdog.sh)
}

menu_setup() {
    bash <(wget -qO ${REPO}/menu/update.sh)
}

restart_services() {
  systemctl enable xray haproxy nginx runn
  systemctl restart xray haproxy nginx runn
  systemctl enable udp-custom
  systemctl restart udp-custom
  systemctl enable server
  systemctl restart server
  systemctl enable client
  systemctl restart client
  systemctl enable rc-local
  systemctl restart rc-local.service
  systemctl enable badvpn1 badvpn2 badvpn3
  systemctl restart badvpn1 badvpn2 badvpn3
}

function install_success() {
  clear
  rm -f Install.sh 
  lane_atas
  tengah "INSTALASI SUKSES" "${BGREEN}${WHITE}${BOLD}" 1
  lane_bawah
  echo -e ""
  read -p " Press ${YELLOW}[ Enter ]${RESET} to Reboot"
  reboot
}

# --- Alur Pemasangan ---
clear
apt update -y
apt upgrade -y
apt install curl -y

permission
make_folder_xray
domain_setup
first_setup
sshvpn_setup
sshws_setup
xray_setup
udp_setup
slowdns_setup
br_setup
watchdog_setup
menu_setup

restart_services
install_success
