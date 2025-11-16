#!/bin/bash
# Mod By Beby VPN 
# VERSI PERBAIKAN: Perbaikan webroot, path PAM (multi-arsitektur), dan service management.
# ==================================================
# Link Hosting Kalian
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"

# initialisasi var
export DEBIAN_FRONTEND=noninteractive
OS=`uname -m`;
# PERBAIKAN: Konsistensi dan keamanan, gunakan ipv4.
MYIP=$(curl -sS ipv4.icanhazip.com);
ANU=$(ip -o -4 route show to default | awk '{print $5}');
# PERBAIKAN: Variabel 'domain' dihapus (tidak terpakai)

# Install OpenVPN dan Easy-RSA
apt install openvpn easy-rsa unzip -y
# Redundansi aman, pastikan iptables-persistent ada
apt install openssl iptables iptables-persistent -y
mkdir -p /etc/openvpn/server/easy-rsa/
cd /etc/openvpn/
wget ${REPO}install/vpn.zip
unzip -o vpn.zip
rm -f vpn.zip
chown -R root:root /etc/openvpn/server/easy-rsa/

cd
mkdir -p /usr/lib/openvpn/

PAM_PATH=$(find /usr/lib -name openvpn-plugin-auth-pam.so -print -quit)
if [ -n "$PAM_PATH" ] && [ -f "$PAM_PATH" ]; then
  cp "$PAM_PATH" /usr/lib/openvpn/openvpn-plugin-auth-pam.so
  echo -e "${CYAN}Plugin PAM ditemukan dan disalin dari: $PAM_PATH${RESET}"
else
  # Coba path fallback jika find gagal (jarang terjadi)
  echo -e "${CYAN}Plugin PAM tidak ditemukan oleh 'find', mencoba path fallback...${RESET}"
  cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so 2>/dev/null || \
  cp /usr/lib/aarch64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so 2>/dev/null || \
  echo -e "${RED}PERINGATAN: ${CYAN}Plugin openvpn-plugin-auth-pam.so tidak ditemukan. Otentikasi PAM mungkin gagal.${RESET}"
fi
# --- AKHIR PERBAIKAN PAM ---

# nano /etc/default/openvpn
sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn

# --- PERBAIKAN FATAL: Manajemen Layanan ---
# Gunakan systemctl modern, bukan init.d
systemctl enable --now openvpn-server@server-tcp
systemctl enable --now openvpn-server@server-udp
systemctl restart openvpn-server@server-tcp openvpn-server@server-udp
# --- AKHIR PERBAIKAN ---

# aktifkan ip4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# Buat config client TCP 1194
cat > /etc/openvpn/tcp.ovpn <<-END
client
dev tun
proto tcp
remote $MYIP 1194
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
END

# Buat config client UDP 2200
cat > /etc/openvpn/udp.ovpn <<-END
client
dev tun
proto udp
remote $MYIP 2200
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
END

# Buat config client SSL
cat > /etc/openvpn/ssl.ovpn <<-END
client
dev tun
proto tcp
remote $MYIP 990
resolv-retry infinite
route-method exe
nobind
persist-key
persist-tun
auth-user-pass
comp-lzo
verb 3
END

cd
# PERBAIKAN: Hapus restart init.d yang salah
# /etc/init.d/openvpn restart

# masukkan certificatenya ke dalam config client TCP 1194
echo '<ca>' >> /etc/openvpn/tcp.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/tcp.ovpn
echo '</ca>' >> /etc/openvpn/tcp.ovpn

# --- PERBAIKAN FATAL: Path Webroot ---
# Ganti /var/www/html ke /home/vps/public_html agar sesuai Nginx
WEBROOT="/home/vps/public_html"
mkdir -p "$WEBROOT"
cp /etc/openvpn/tcp.ovpn ${WEBROOT}/tcp.ovpn

# masukkan certificatenya ke dalam config client UDP 2200
echo '<ca>' >> /etc/openvpn/udp.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/udp.ovpn
echo '</ca>' >> /etc/openvpn/udp.ovpn
cp /etc/openvpn/udp.ovpn ${WEBROOT}/udp.ovpn

# masukkan certificatenya ke dalam config client SSL
echo '<ca>' >> /etc/openvpn/ssl.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/ssl.ovpn
echo '</ca>' >> /etc/openvpn/ssl.ovpn
cp /etc/openvpn/ssl.ovpn ${WEBROOT}/ssl.ovpn

# --- PERBAIKAN FATAL: Path Webroot dan Link Rusak ---
cat >${WEBROOT}/index.html <<EOF
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Informasi</title>
    <meta name="description" content="Info Script Dan Profile" />
    <meta name="theme-color" content="#000000" />
    <meta property="og:image" content="https://raw.githubusercontent.com/diah082/vip/main/Assets/autosc.jpg" />
    <link rel="stylesheet" href="https://use.fontawesome.com/releases/v5.8.2/css/all.css">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/4.3.1/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/mdbootstrap/4.8.3/css/mdb.min.css" rel="stylesheet">
    <style>
        body {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
            font-family: Arial, sans-serif;
            color: white;
            text-align: center;
            /* PERBAIKAN: Ganti http ke https */
            background: url('https://raw.githubusercontent.com/diah082/nebot/main/Assets/banner.jpg') no-repeat center center/cover;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        .container {
            background: rgba(0, 0, 0, 0.6);
            padding: 2rem;
            border-radius: 20px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
            max-width: 800px;
            margin-top: 2rem;
        }
        h1, p {
            margin: 10px 0;
        }
        .contact a {
            color: #00bcd4;
            text-decoration: none;
            margin: 0 10px;
            transition: 0.3s;
        }
        .contact a:hover {
            color: #03a9f4;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Informasi Script & Profil</h1>
        <p><strong>Script:</strong> Sistem otomatisasi berbasis Go dan Bash untuk proxy tunneling dan manajemen server.</p>
        <p><strong>Profil:</strong> Developer dengan fokus pada optimalisasi script, keamanan, dan integrasi multi-platform.</p>
        <p><strong>Catatan:</strong> Jika Membutuhkan info Detail Akun silakhan Hubungi Admin dengan mengirimkan Struk Pembelian Terimaksih.</p>
        <div class="contact">
            <h2>Kontak Saya</h2>
            <p>
                📞 <a href="https://whatsapp.nevpn.site" target="_blank">WhatsApp</a>
                | 📬 <a href="https://nevpn.site" target="_blank">Telegram</a>
            </p>
        </div>
    </div>

    <div class="container">
	    <img src="https://openvpn.net/wp-content/uploads/openvpn.jpg" class="card-img-top">
        <div class="mask rgba-white-slight"></div>
        <h5 class="card-title">Config List</h5>
        <br />
        <ul class="list-group">
            <li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;">
                <p>TCP <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /></p>
                <a class="btn btn-outline-success waves-effect btn-sm" href="https://$MYIP/tcp.ovpn" style="float:right;">
                    <i class="fa fa-download"></i> Download
                </a>
            </li>
            <li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;">
                <p>UDP <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /></p>
                <a class="btn btn-outline-success waves-effect btn-sm" href="https://$MYIP/udp.ovpn" style="float:right;">
                    <i class="fa fa-download"></i> Download
                </a>
            </li>
            <li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;">
                <p>SSL <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /></p>
                <a class="btn btn-outline-success waves-effect btn-sm" href="https://$MYIP/ssl.ovpn" style="float:right;">
                    <i class="fa fa-download"></i> Download
                </a>
            </li>
            <li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;">
                <p>WS SSL <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /></p>
                <a class="btn btn-outline-success waves-effect btn-sm" href="https://$MYIP/ws-ssl.ovpn" style="float:right;">
                    <i class="fa fa-download"></i> Download
                </a>
            </li>
            <li class="list-group-item justify-content-between align-items-center" style="margin-bottom:1em;">
                <p>ALL.zip <span class="badge light-blue darken-4">Android/iOS/PC/Modem</span><br /></p>
                <a class="btn btn-outline-success waves-effect btn-sm" href="https://$MYIP/openvpn.zip" style="float:right;">
                    <i class="fa fa-download"></i> Download
                </a>
            </li>
        </ul>
    </div>
</body>
</html>

EOF
cd ${WEBROOT}
zip openvpn.zip tcp.ovpn udp.ovpn ssl.ovpn

# PERBAIKAN: Hapus download index.html yang salah dan tidak perlu
# wget -qO /usr/share/nginx/html/index.html ...
# sed -i "s/xxx/${domain}/" /usr/share/nginx/html/index.html

cd
iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $ANU -j MASQUERADE
iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $ANU -j MASQUERADE
iptables-save > /etc/iptables.up.rules
chmod +x /etc/iptables.up.rules

iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# PERBAIKAN: Restart layanan yang benar di akhir
systemctl restart openvpn-server@server-tcp openvpn-server@server-udp

# Delete script
history -c
# PERBAIKAN: Hapus file skrip ini, bukan file di /root/
rm -f "$0"
