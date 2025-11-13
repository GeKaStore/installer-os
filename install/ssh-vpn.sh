#!/bin/bash

# Men-set agar skrip berhenti jika ada perintah yang gagal
set -e

# initializing var
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"
export DEBIAN_FRONTEND=noninteractive

# --- Pengecekan Dependensi Kritis ---
# Skrip ini bergantung pada file-file ini. Jika tidak ada, skrip harus berhenti.
echo "Memeriksa dependensi file..."

if [ ! -f /etc/xray/domain ]; then
    echo "Kesalahan: File /etc/xray/domain tidak ditemukan."
    echo "Pastikan domain Anda sudah diatur dengan benar sebelum menjalankan ini."
    exit 1
fi
# --- Pengecekan Selesai ---

MYIP=$(curl -sS ipv4.icanhazip.com)
domain=$(cat /etc/xray/domain)
MYIP2="s/xxxxxxxxx/$MYIP/g"

# $ANU tidak terdefinisi, tapi perintahnya tetap berfungsi.
# Ini cara yang lebih bersih untuk mendapatkan interface utama.
NET=$(ip -o -4 route show to default | awk '{print $5}')

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID

    echo "Menemukan sistem operasi: $OS_NAME $OS_VERSION"
else
    echo "Tidak dapat menentukan sistem operasi."
    exit 1
fi

# detail nama perusahaan
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

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# install webserver
# Menambahkan 'lsof' yang diperlukan nanti
# install webserver
# Menambahkan 'lsof' yang diperlukan nanti
echo "Menginstal paket webserver dan dependensi..."
apt -y install nginx php php-fpm php-cli php-mysql libxml-parser-perl lsof

rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default
curl ${REPO}install/nginx.conf > /etc/nginx/nginx.conf
curl ${REPO}install/vps.conf > /etc/nginx/conf.d/vps.conf
wget -O /etc/haproxy/haproxy.cfg "${REPO}install/haproxy.cfg"
wget -O /etc/nginx/conf.d/xray.conf "${REPO}install/xray.conf"

echo "Mencari file konfigurasi PHP-FPM (www.conf)..."
# PERBAIKAN: Gunakan 'find' untuk mencari file www.conf di mana pun dia berada
PHP_FPM_CONF_PATH=$(find /etc/php/ -name www.conf -print -quit)

if [ -n "$PHP_FPM_CONF_PATH" ] && [ -f "$PHP_FPM_CONF_PATH" ]; then
    echo "File ditemukan di: $PHP_FPM_CONF_PATH"
    # Sekarang kita edit file di path yang benar
    sed -i 's/listen = \/var\/run\/php-fpm.sock/listen = 127.0.0.1:9000/g' "$PHP_FPM_CONF_PATH"
else
    echo "PERINGATAN: Tidak dapat menemukan file 'www.conf' PHP-FPM."
    echo "Melewati konfigurasi listen PHP-FPM."
fi

mkdir -p /home/vps/public_html
echo "<?php phpinfo() ?>" > /home/vps/public_html/info.php
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html
cd /home/vps/public_html
wget -O /home/vps/public_html/index.html "${REPO}install/index.html1"

# Menghentikan webserver yang mungkin berjalan di port 80
echo "Menghentikan webserver yang ada..."
STOPWEBSERVER=$(lsof -i:80 | awk 'NR==2 {print $1}')
[[ -n "$STOPWEBSERVER" ]] && systemctl stop "$STOPWEBSERVER"

## crt xray
echo "Meminta sertifikat SSL untuk $domain..."
systemctl stop nginx
systemctl stop haproxy
mkdir -p /root/.acme.sh
curl https://get.acme.sh | sh -s email=fazligismail@gmail.com
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# --- PERBAIKAN KESALAHAN SINTAKSIS FATAL ---
# Blok ini sebelumnya rusak. Sekarang menggunakan 'cat EOF' (heredoc) yang benar.
echo "Membuat skrip auto-renew SSL..."
cat > /usr/local/bin/ssl_renew.sh <<EOF
#!/bin/bash
/etc/init.d/nginx stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
/etc/init.d/nginx status
EOF
# --- AKHIR PERBAIKAN ---

chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi

echo "Menerapkan domain $domain ke konfigurasi..."
sed -i "s/xxx/$domain/g" /etc/nginx/conf.d/xray.conf
sed -i "s/xxx/$domain/g" /etc/haproxy/haproxy.cfg
cat /etc/xray/xray.key /etc/xray/xray.crt | tee /etc/haproxy/hap.pem

# install badvpn
echo "Menginstal Badvpn (UDP Custom)..."
cd
wget -O /usr/sbin/badvpn "${REPO}install/badvpn" >/dev/null 2>&1
chmod +x /usr/sbin/badvpn > /dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn1.service "${REPO}install/badvpn1.service" >/dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn2.service "${REPO}install/badvpn2.service" >/dev/null 2>&1
wget -q -O /etc/systemd/system/badvpn3.service "${REPO}install/badvpn3.service" >/dev/null 2>&1
systemctl disable badvpn1 badvpn2 badvpn3
systemctl stop badvpn1 badvpn2 badvpn3
systemctl enable badvpn1 badvpn2 badvpn3
systemctl start badvpn1 badvpn2 badvpn3
cd

echo "Menambahkan port SSH tambahan..."
sed -i '/Port 22/a Port 500' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 40000' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 51443' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 58080' /etc/ssh/sshd_config
sed -i '/Port 22/a Port 200' /etc/ssh/sshd_config
# Baris ini redundan, Port 22 sudah ada
# sed -i '/Port 22/a Port 22' /etc/ssh/sshd_config
/etc/init.d/ssh restart

echo "=== Install Dropbear ==="
# install dropbear
apt -y install dropbear
sudo dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
sudo chmod 600 /etc/dropbear/dropbear_dss_host_key
wget -O /etc/default/dropbear "${REPO}install/dropbear"
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
/etc/init.d/ssh restart
/etc/init.d/dropbear restart
wget -q ${REPO}install/setrsyslog.sh && chmod +x setrsyslog.sh && ./setrsyslog.sh

echo "Menginstal Squid Proxy..."
if [[ "$OS_NAME" == "debian" && "$OS_VERSION" == "10" ]] || [[ "$OS_NAME" == "ubuntu" && "$OS_VERSION" == "20.04" ]]; then
    echo "Menginstal squid3 untuk Debian 10 atau Ubuntu 20.04..."
    apt -y install squid3
else
    echo "Menginstal squid untuk versi lain..."
    apt -y install squid
fi
# Unduh file konfigurasi
echo "Mengunduh file konfigurasi Squid..."
wget -O /etc/squid/squid.conf "${REPO}install/squid3.conf"

# Ganti placeholder dengan alamat IP
echo "Mengganti placeholder IP dengan $MYIP..."
sed -i $MYIP2 /etc/squid/squid.conf

echo "Instalasi dan konfigurasi Squid selesai."

# setting vnstat
echo "Menginstal vnstat..."
apt -y install vnstat
/etc/init.d/vnstat restart
apt -y install libsqlite3-dev
wget https://humdi.net/vnstat/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
./configure --prefix=/usr --sysconfdir=/etc && make && make install
cd
vnstat -i $NET
sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf
chown vnstat:vnstat /var/lib/vnstat -R
systemctl enable vnstat
/etc/init.d/vnstat restart
rm -f /root/vnstat-2.6.tar.gz
rm -rf /root/vnstat-2.6

cd
wget ${REPO}install/vpn.sh &&  chmod +x vpn.sh && ./vpn.sh
wget ${REPO}install/lolcat.sh &&  chmod +x lolcat.sh && ./lolcat.sh
cd
echo "Membuat file swap 2GB..."

# Cek dulu kalau filenya udah ada
if [ -f /swapfile ]; then
    echo "File /swapfile sudah ada, melewati pembuatan."
else
    # PERBAIKAN 1: Gunakan fallocate, 100x lebih cepat dari dd
    fallocate -l 2G /swapfile
    
    # Amankan izinnya DULU
    chmod 0600 /swapfile
    
    # Baru format ke swap
    mkswap /swapfile
fi

# Cek apakah swap sudah aktif atau belum
if swapon --show | grep -q '/swapfile'; then
    echo "Swap /swapfile sudah aktif."
else
    # Aktifkan swap
    swapon /swapfile
fi

# PERBAIKAN 2: Cek fstab dulu sebelum nambah (Aman!)
if ! grep -q '/swapfile' /etc/fstab; then
    echo "Menambahkan swap ke /etc/fstab..."
    # Gunakan 'echo >>' yang lebih aman dan jelas
    echo '/swapfile      swap swap   defaults    0 0' >> /etc/fstab
else
    echo "Swap sudah ada di /etc/fstab."
fi

echo "Menginstal DDOS Deflate..."

# Cek direktori
if [ -d '/usr/local/ddos' ]; then
	echo "DDOS Deflate sudah terinstal. Melewati."
else
    # PERBAIKAN 1: Ganti URL ke mirror GitHub yang masih hidup
    local REPO_URL="https://raw.githubusercontent.com/jgmdev/ddos-deflate/master"

	mkdir /usr/local/ddos
    echo "Mengunduh file sumber dari mirror..."
    
    wget -q -O /usr/local/ddos/ddos.conf "${REPO_URL}/ddos.conf"
    wget -q -O /usr/local/ddos/LICENSE "${REPO_URL}/LICENSE"
    wget -q -O /usr/local/ddos/ignore.ip.list "${REPO_URL}/ignore.ip.list"
    wget -q -O /usr/local/ddos/ddos.sh "${REPO_URL}/ddos.sh"
    echo "Download selesai."

    # Pastikan file utamanya ada
    if [ ! -s /usr/local/ddos/ddos.sh ]; then
        echo "Gagal mengunduh skrip ddos.sh. Instalasi dibatalkan."
        rm -rf /usr/local/ddos
        exit 1
    fi
    
    chmod 0755 /usr/local/ddos/ddos.sh
    
    # PERBAIKAN 2: Gunakan 'ln -sf' (symbolic link, force)
    # Ini lebih standar dan aman daripada 'cp -s'
    ln -sf /usr/local/ddos/ddos.sh /usr/local/bin/ddos
    
    echo "Membuat cron (dijamin tidak duplikat)..."
    
    # PERBAIKAN 3: Hapus cron lama dulu (jika ada)
    (crontab -l 2>/dev/null | grep -v 'ddos.sh') | crontab -
    
    # Baru jalankan installer cron-nya
    /usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
    
    echo "Instalasi selesai."
    echo "File konfigurasi ada di /usr/local/ddos/ddos.conf"
fi
clear

echo "Mengatur Banner SSH..."
echo "Banner /etc/issue.net" >>/etc/ssh/sshd_config
wget -O /etc/issue.net "${REPO}install/issue.net"
wget ${REPO}install/bbr.sh && chmod +x bbr.sh && ./bbr.sh
wget -q ${REPO}install/ipserver && chmod +x ipserver && ./ipserver

echo "Mengatur aturan firewall (blokir torrent)..."
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
rm -f ipserver
wget -O /etc/issue.net "${REPO}install/issue.net"
cd

echo "Mengatur pekerjaan cron..."
cat> /etc/cron.d/xp_otm << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/xp
END
cat> /etc/cron.d/bckp_otm << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 22 * * * root /usr/bin/backup
END

cat> /etc/cron.d/cpu_otm << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/5 * * * * root /usr/bin/autocpu
END
wget -O /usr/bin/autocpu "${REPO}install/autocpu.sh" && chmod +x /usr/bin/autocpu

cat >/etc/cron.d/xp_sc <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		1 0 * * * root /usr/bin/expsc
	END

cat >/etc/cron.d/logclean <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root truncate -s 0 /var/log/syslog \
    && truncate -s 0 /var/log/nginx/error.log \
    && truncate -s 0 /var/log/nginx/access.log \
    && truncate -s 0 /var/log/xray/error.log \
    && truncate -s 0 /var/log/xray/access.log
END

cat >/etc/cron.d/daily_reboot <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
5 0 * * * root /sbin/reboot
END

service cron restart >/dev/null 2>&1
service cron reload >/dev/null 2>&1
service cron start >/dev/null 2>&1

chown -R www-data:www-data /home/vps/public_html

echo "Membersihkan file instalasi..."
rm -f /root/key.pem
rm -f /root/cert.pem
rm -f /root/ssh-vpn.sh
rm -f /root/bbr.sh

echo "Instalasi selesai."
clear
