#!/bin/bash
# Skrip ini menginstal layanan 'limit-ip' untuk berbagai protokol Xray.

source /usr/local/bin/ui.sh
clear

# PERBAIKAN: Variabel MYIP dihapus karena tidak pernah digunakan.
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"

lane_atas
tengah "CONFIGURE IP LIMIT" "${BRED}${WHITE}" 1
lane_bawah

wget -q -O /usr/bin/limit-ip "${REPO}install/limit-ip"

chmod +x /usr/bin/limit-ip

# PERBAIKAN: Menjalankan sed pada path lengkap, tidak perlu 'cd'
sed -i 's/\r//' /usr/bin/limit-ip

# Unduh skrip data/helper untuk setiap protokol
wget -q -O /etc/xray/limit.vmess "${REPO}install/vmess"
wget -q -O /etc/xray/limit.vless "${REPO}install/vless"
wget -q -O /etc/xray/limit.trojan "${REPO}install/trojan"
wget -q -O /etc/xray/limit.shadowsocks "${REPO}install/shadowsocks"

# Beri izin eksekusi pada skrip-skrip ini (Ini benar, karena ini skrip)
chmod +x /etc/xray/limit.vmess
chmod +x /etc/xray/limit.vless
chmod +x /etc/xray/limit.trojan
chmod +x /etc/xray/limit.shadowsocks

# PERBAIKAN: Hapus daemon-reload pertama yang tidak perlu di sini.

# Unduh file layanan systemd
wget -q -O /etc/systemd/system/limitvmess.service "${REPO}install/limitvmess.service"
wget -q -O /etc/systemd/system/limitvless.service "${REPO}install/limitvless.service"
wget -q -O /etc/systemd/system/limittrojan.service "${REPO}install/limittrojan.service"
wget -q -O /etc/systemd/system/limitshadowsocks.service "${REPO}install/limitshadowsocks.service"

# Muat ulang daemon dan mulai semua layanan
systemctl daemon-reload

systemctl enable --now limitvmess
systemctl enable --now limitvless
systemctl enable --now limittrojan
systemctl enable --now limitshadowsocks

rm -f "$0"