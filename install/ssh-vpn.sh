#!/bin/bash

# Men-set agar skrip berhenti jika ada perintah yang gagal
# set -e

source /usr/local/bin/ui.sh
clear

# PERBAIKAN: Selalu jalankan update dulu!
apt update -y
# ---

lane_atas
tengah "CONFIGURE SSH VPN" "${BRED}${WHITE}" 1
lane_bawah

# Inisialisasi var
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"
export DEBIAN_FRONTEND=noninteractive

# --- Pengecekan Dependensi Kritis ---
echo "Memeriksa dependensi file..."
if [ ! -f /etc/xray/domain ]; then
    echo -e "${RED}Domain tidak ditemukan.${RESET}"
    exit 1
fi
# --- Pengecekan Selesai ---

MYIP=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /etc/xray/domain)
# String pengganti untuk sed
MYIP2="s/xxxxxxxxx/$MYIP/g"

# Dapatkan interface jaringan utama
NET=$(ip -o -4 route show to default | awk '{print $5}')

# Deteksi OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
    echo -e "Menemukan sistem operasi: ${BLUE}$OS_NAME $OS_VERSION${RESET}"
else
    echo -e "${RED}Tidak dapat menentukan sistem operasi.${RESET}"
    exit 1
fi

# detail nama perusahaan (untuk sertifikat)
country=ID
state=Indonesia
locality=Jakarta
organization=none
organizationalunit=none
commonname=none
email=none

# go to root
cd

# Edit file /etc/systemd/system/rc-local.service
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# nano /etc/rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

# Ubah izin akses
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# disable ipv6 (ditambahkan ke rc.local agar permanen)
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

# Pengerasan SSH
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# install webserver
# lsof dan iptables-persistent sudah diinstal oleh Install.sh,
# tapi tidak masalah jika ada di sini lagi (redundansi aman).
echo "Menginstal paket webserver dan dependensi..."
apt -y install nginx php php-fpm php-cli php-mysql libxml-parser-perl lsof iptables-persistent netfilter-persistent

# Hapus konfigurasi default nginx
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default

# Unduh konfigurasi kustom
curl ${REPO}install/nginx.conf > /etc/nginx/nginx.conf
curl ${REPO}install/vps.conf > /etc/nginx/conf.d/vps.conf
wget -O /etc/haproxy/haproxy.cfg "${REPO}install/haproxy.cfg"
wget -O /etc/nginx/conf.d/xray.conf "${REPO}install/xray.conf"

echo "Mencari file konfigurasi PHP-FPM (www.conf)..."
# PERBAIKAN: Gunakan 'find' untuk mencari file www.conf di mana pun dia berada
# Ini adalah cara yang SANGAT BAGUS untuk kompatibilitas multi-OS.
PHP_FPM_CONF_PATH=$(find /etc/php/ -name www.conf -print -quit)

if [ -n "$PHP_FPM_CONF_PATH" ] && [ -f "$PHP_FPM_CONF_PATH" ]; then
    echo "${CYAN}File ditemukan di: $PHP_FPM_CONF_PATH${RESET}"
    # Sekarang kita edit file di path yang benar
    sed -i 's/listen = \/var\/run\/php-fpm.sock/listen = 127.0.0.1:9000/g' "$PHP_FPM_CONF_PATH"
else
    echo -e "${CYAN}PERINGATAN: Tidak dapat menemukan file 'www.conf' PHP-FPM.${RESET}"
    echo -e "${CYAN}Melewati konfigurasi listen PHP-FPM.${RESET}"
fi

# Siapkan direktori web
# PERBAIKAN: Install.sh menggunakan /var/www/html, skrip ini pakai /home/vps/public_html
# Saya akan ikuti skrip ini, tapi pastikan Anda konsisten.
mkdir -p /home/vps/public_html
echo "<?php phpinfo() ?>" > /home/vps/public_html/info.php
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html
cd /home/vps/public_html
wget -O /home/vps/public_html/index.html "${REPO}install/index.html1"

# Menghentikan webserver yang mungkin berjalan di port 80
STOPWEBSERVER=$(lsof -i:80 | awk 'NR==2 {print $1}')
[[ -n "$STOPWEBSERVER" ]] && systemctl stop "$STOPWEBSERVER"

## crt xray
echo "${CYAN}Meminta sertifikat SSL untuk $domain...${RESET}"
systemctl stop nginx
systemctl stop haproxy
mkdir /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

cat > /usr/local/bin/ssl_renew.sh <<EOF
#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
/etc/init.d/nginx status
EOF
# --- AKHIR PERBAIKAN ---

chmod +x /usr/local/bin/ssl_renew.sh
# Menambahkan cronjob (cara aman, anti-duplikat)
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l 2>/dev/null;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab -;fi

sed -i "s/xxx/$domain/g" /etc/nginx/conf.d/xray.conf
sed -i "s/xxx/$domain/g" /etc/haproxy/haproxy.cfg
# Gabungkan key dan crt untuk HAProxy
cat /etc/xray/xray.key /etc/xray/xray.crt | tee /etc/haproxy/hap.pem

clear

# install badvpn
lane_atas
tengah "CONFIGURE BADVPN (UDP CUSTOM)" "${BRED}${WHITE}" 1
lane_bawah
cd

wget -O /usr/sbin/badvpn "${REPO}install/badvpn"

# --- PERBAIKAN: Tambahkan Pengecekan Unduhan ---
if [ ! -s /usr/sbin/badvpn ]; then
    echo -e "${RED}FATAL: Gagal mengunduh badvpn binary. (File tidak ada atau 0 byte).${RESET}"
    exit 1
fi
# --- AKHIR PERBAIKAN ---

chmod +x /usr/sbin/badvpn

wget -O /etc/systemd/system/badvpn1.service "${REPO}install/badvpn1.service"
wget -O /etc/systemd/system/badvpn2.service "${REPO}install/badvpn2.service"
wget -O /etc/systemd/system/badvpn3.service "${REPO}install/badvpn3.service"

systemctl daemon-reload
systemctl enable badvpn1 badvpn2 badvpn3
systemctl start badvpn1 badvpn2 badvpn3
cd

sed -i '/Port 22/a Port 500' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 40000' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 51443' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 58080' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 200' /etc/ssh/sshd_config
systemctl restart ssh

clear

lane_atas
tengah "CONFIGURE DROPBEAR" "${BRED}${WHITE}" 1
lane_bawah

apt -y install dropbear
sudo dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
sudo chmod 600 /etc/dropbear/dropbear_dss_host_key
wget -O /etc/default/dropbear "${REPO}install/dropbear"
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
systemctl restart ssh
systemctl restart dropbear

# Unduh dan jalankan skrip rsyslog
wget -q ${REPO}install/setrsyslog.sh && chmod +x setrsyslog.sh && ./setrsyslog.sh

clear

lane_atas
tengah "CONFIGURE SQUID PROXY" "${BRED}${WHITE}" 1
lane_bawah

# Logika ini sudah benar, dipertahankan.
if [[ "$OS_NAME" == "debian" && "$OS_VERSION" == "10" ]] || [[ "$OS_NAME" == "ubuntu" && "$OS_VERSION" == "20.04" ]]; then
    echo -e "${CYAN}Menginstal squid3 untuk $OS_NAME $OS_VERSION${RESET}"
    apt -y install squid3
else
    echo -e "${CYAN}Menginstal squid3 untuk $OS_NAME $OS_VERSION${RESET}"
    apt -y install squid
fi

wget -O /etc/squid/squid.conf "${REPO}install/squid3.conf"
sed -i $MYIP2 /etc/squid/squid.conf

clear

sed -i "s/Interface \"eth0\"/Interface \"$NET\"/g" /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
systemctl restart vnstat

cd
# Unduh dan jalankan skrip lain
wget ${REPO}install/vpn.sh &&  chmod +x vpn.sh && ./vpn.sh
wget ${REPO}install/lolcat.sh &&  chmod +x lolcat.sh && ./lolcat.sh
cd

clear

lane_atas
tengah "CONFIGURE SWAP 2GB" "${BRED}${WHITE}" 1
lane_bawah

# Cek dulu kalau filenya udah ada
if [ -f /swapfile ]; then
    echo -e "${CYAN}File /swapfile sudah ada, melewati pembuatan.${RESET}"
else
    # PERBAIKAN 1: Gunakan fallocate, 100x lebih cepat dari dd
    fallocate -l 2G /swapfile
    chmod 0600 /swapfile
    mkswap /swapfile
fi

# Cek apakah swap sudah aktif
if swapon --show | grep -q '/swapfile'; then
    echo -e "${CYAN}Swap /swapfile sudah aktif.${RESET}"
else
    swapon /swapfile
fi

# PERBAIKAN 2: Cek fstab dulu sebelum nambah (Aman!)
if ! grep -q '/swapfile' /etc/fstab; then
    echo '/swapfile      swap swap   defaults    0 0' >> /etc/fstab
else
    echo -e "${CYAN}Swap sudah ada di /etc/fstab.${RESET}"
fi
# --- AKHIR PERBAIKAN SWAP ---

clear

lane_atas
tengah "CONFIGURE DDOS DEFLATE" "${BRED}${WHITE}" 1
lane_bawah

if [ -d '/usr/local/ddos' ]; then
	echo -e "${CYAN}DDOS Deflate sudah terinstal. Melewati.${RESET}"
else
    # PERBAIKAN 1: Ganti URL ke mirror GitHub yang masih hidup
    REPO_URL="https://raw.githubusercontent.com/jgmdev/ddos-deflate/master"

	mkdir /usr/local/ddos
    wget -q -O /usr/local/ddos/ddos.conf "${REPO_URL}/ddos.conf"
    wget -q -O /usr/local/ddos/LICENSE "${REPO_URL}/LICENSE"
    wget -q -O /usr/local/ddos/ignore.ip.list "${REPO_URL}/ignore.ip.list"
    wget -q -O /usr/local/ddos/ddos.sh "${REPO_URL}/ddos.sh"

    if [ ! -s /usr/local/ddos/ddos.sh ]; then
        echo -e "${RED}Gagal mengunduh ddos.sh. Instalasi dibatalkan.${RESET}"
        rm -rf /usr/local/ddos
        # Kita tidak keluar 'exit 1' agar instalasi lain bisa lanjut
    else
        chmod 0755 /usr/local/ddos/ddos.sh
        # PERBAIKAN 2: Gunakan 'ln -sf' (symbolic link, force)
        ln -sf /usr/local/ddos/ddos.sh /usr/local/bin/ddos
        
        # PERBAIKAN 3: Hapus cron lama dulu (jika ada)
        (crontab -l 2>/dev/null | grep -v 'ddos.sh') | crontab -
        # Baru jalankan installer cron-nya
        /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    fi
fi
# --- AKHIR PERBAIKAN DDOS ---

clear

if ! grep -q "Banner /etc/issue.net" /etc/ssh/sshd_config; then
    echo "Banner /etc/issue.net" >>/etc/ssh/sshd_config
fi

wget -O /etc/issue.net "${REPO}install/issue.net"
# Unduh dan jalankan skrip lain
wget ${REPO}install/bbr.sh && chmod +x bbr.sh && ./bbr.sh
wget -q ${REPO}install/ipserver && chmod +x ipserver && ./ipserver

iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
# --- PERBAIKAN TYPO FATAL ---
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
# --- AKHIR PERBAIKAN ---
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
rm -f ipserver
cd

clear

lane_atas
tengah "CONFIGURE CRON" "${BRED}${WHITE}" 1
lane_bawah

# Menggunakan 'tee' untuk menimpa file, lebih bersih.
tee /etc/cron.d/xp_otm > /dev/null << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
END

tee /etc/cron.d/bckp_otm > /dev/null << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 22 * * * root /usr/bin/backup
END

# --- PERBAIKAN: Menghapus cron autocpu (benalu) ---
rm -f /etc/cron.d/cpu_otm
# --- AKHIR PERBAIKAN ---

tee /etc/cron.d/xp_sc > /dev/null <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
1 0 * * * root /usr/bin/expsc
END

tee /etc/cron.d/logclean > /dev/null <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root truncate -s 0 /var/log/syslog \
    && truncate -s 0 /var/log/nginx/error.log \
    && truncate -s 0 /var/log/nginx/access.log \
    && truncate -s 0 /var/log/xray/error.log \
    && truncate -s 0 /var/log/xray/access.log
END

tee /etc/cron.d/daily_reboot > /dev/null <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
5 0 * * * root /sbin/reboot
END

# PERBAIKAN: Gunakan systemctl
systemctl restart cron
# --- AKHIR PERBAIKAN ---

chown -R www-data:www-data /home/vps/public_html

rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh
rm -f /root/bbr.sh
# Hapus skrip yang di-download
rm -f /root/vpn.sh
rm -f /root/lolcat.sh
rm -f /root/setrsyslog.sh

clear
rm -f "$0"
