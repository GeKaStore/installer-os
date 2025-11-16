#!/bin/bash

source /usr/local/bin/ui.sh
clear

MYIP=$(curl -sS ipv4.icanhazip.com)
ipsaya=$(curl -sS ipv4.icanhazip.com)
HOSTNAME=$(hostname)
repo="https://raw.githubusercontent.com/GeKaStore/installer-os/main"

NODE_VERSION=$(node -v 2>/dev/null | grep -oP '(?<=v)\d+' || echo "0")

# PERBAIKAN: Hapus 'rm lock' di sini, sudah ada di bawah
# rm /var/lib/dpkg/stato*
# rm /var/lib/dpkg/lock*

if [ "$NODE_VERSION" -lt 22 ]; then
    echo -e "${CYAN}Menginstal atau meningkatkan Node.js ke v22...${neutrRESETal}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - || echo -e "${red}Gagal mengunduh setup Node.js${neutral}"
    apt-get install -y nodejs || echo -e "${RED}Gagal menginstal Node.js${RESET}"
    npm install -g npm@latest
else
    echo -e "${CYAN}Node.js sudah v$NODE_VERSION, melewati...${RESET}"
fi

# Fungsi ini sudah bagus, mengganti mawk ke gawk (penting)
check_and_install_gawk() {
    if ls -l /etc/alternatives/awk | grep -q "/usr/bin/mawk"; then
        echo -e "${BLUE}[INFO]${RESET} mawk terdeteksi, mengganti ke gawk..."
        if ! command -v gawk &> /dev/null; then
            echo -e "${BLUE}[INFO]${RESET} Menginstal gawk..."
            apt update &> /dev/null && apt install gawk -y &> /dev/null
        fi
        if command -v gawk &> /dev/null; then
            echo -e "${BLUE}[INFO]${RESET} gawk berhasil diinstal. Mengatur gawk sebagai default awk..."
            ln -sf $(which gawk) /usr/bin/awk
        else
            echo -e "${RED}[ERROR]${RESET} Gagal menginstal gawk. Update dihentikan."
            exit 1
        fi
    else
        echo -e "${BLUE}[INFO]${RESET} awk sudah menggunakan gawk atau kompatibel."
    fi
}
clear

# Fungsi spinner
loading() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    tput civis
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c] $message\r" "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    tput cnorm
}

# Hapus lock dpkg (cukup sekali)
if [[ $(ls /var/lib/dpkg/ | grep -c "lock") -gt 0 ]]; then
	rm /var/lib/dpkg/lock* &> /dev/null
	rm /var/lib/dpkg/stato* &> /dev/null
fi

# Instal gdown
if ! command -v gdown &> /dev/null; then
    # PERBAIKAN: Typo 'linux 12' -> 'debian 12'
    if grep -Ei 'ubuntu 24|ubuntu 25|debian 12' /etc/os-release &> /dev/null; then
        apt update -y &> /dev/null && apt install -y python3-full python3-pip &> /dev/null
		pip install --break-system-packages gdown &> /dev/null
    else
        apt update -y &> /dev/null && apt install -y python3-pip &> /dev/null
        pip install gdown &> /dev/null
    fi
fi

# Instal dependensi lain dengan spinner
if ! command -v 7z &> /dev/null; then
    apt install p7zip-full -y &> /dev/null &
    loading $! "Loading Install p7zip-full"
fi
if ! command -v sshpass &> /dev/null; then
    apt install sshpass -y &> /dev/null &
    loading $! "Loading Install sshpass"
    apt  install speedtest-cli -y &> /dev/null &
    loading $! "Loading Install SpeedTest"
fi

# Buat file warna
FILE_WARNA="/etc/warna"
if [ ! -f "$FILE_WARNA" ] || [ ! -s "$FILE_WARNA" ]; then
    echo "${BLUE}[INFO]${RESET} Menyiapkan Warna Script..."
    cat <<EOF > "$FILE_WARNA"
start_r=200
start_g=200
start_b=255
mid_r=0
mid_g=0
mid_b=255
end_r=200
end_g=200
end_b=255
EOF
else
    echo "${BLUE}[INFO]${RESET} Warna Script Berhasil Diatur!"
fi

# Cache IP
FILE_IP="/usr/bin/.ipvps"
if [ ! -f "$FILE_IP" ] || [ ! -s "$FILE_IP" ]; then
curl -sS ipv4.icanhazip.com > /usr/bin/.ipvps
fi

# Fungsi perbaikan cron
fixcron() {
cd
cat > /root/fix.sh << 'EOF'
#!/bin/bash
    systemctl stop cron
    wget -qO /usr/lib/systemd/system/cron.service "$repo/install/cron.service" >/dev/null 2>&1
    pkill -f /usr/sbin/cron >/dev/null 2>&1
    pkill -f clearcache >/dev/null 2>&1
    pkill -f menu >/dev/null 2>&1
    pkill -f sleep >/dev/null 2>&1
    systemctl daemon-reexec >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    systemctl restart cron >/dev/null 2>&1
rm -- "$0"
EOF
chmod +x fix.sh
echo "/root/fix.sh" | at now + 5 minute
}

# Fungsi update WS
Updatews() {
systemctl stop ws
wget -qO /usr/bin/ws "$repo/sshws/ws" >/dev/null 2>&1
systemctl start ws >/dev/null 2>&1
}

echo -e " [INFO] Prepare Update Script..."
{
# PERBAIKAN: Sesuaikan webroot
rm /home/vps/public_html/*.txt &> /dev/null

# PERBAIKAN FATAL: Panggilan 'setup_data' dihapus karena tidak terdefinisi
# setup_data

wget -q $repo/install/vpn.sh && chmod +x vpn.sh && ./vpn.sh

# Download file bug
BUG_FILE="/etc/xray/.bug_optr"
BUG_URL="$repo/install/bug"
if [[ -f $BUG_FILE && -s $BUG_FILE && $(grep -i "=" "$BUG_FILE") ]]; then
    echo "File bug sudah ada, melanjutkan."
else
    echo "File bug kosong, mendownload ulang..."
    mkdir -p "$(dirname "$BUG_FILE")"
    curl -o "$BUG_FILE" -s "$BUG_URL"
    if [[ $? -ne 0 ]]; then
        echo "Gagal mendownload file bug."
        # Tidak keluar, lanjutkan update
    fi
fi

# Atur ulang Cron jobs
# PERBAIKAN: Menghapus cron reboot yang diinstal oleh ssh-vpn.sh
# Ini tampaknya disengaja oleh skrip update.
rm /etc/cron.d/*reboot &> /dev/null
rm /etc/cron.d/daily_reboot &> /dev/null

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
cat> /etc/cron.d/logclean << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/10 * * * * root /usr/bin/clearlog
END

# PERBAIKAN FATAL: Nama file diubah agar tidak menimpa cron 'logclean'
cat> /etc/cron.d/clearcache_otm << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 0 * * * root /usr/bin/clearcache
END

cat> /etc/cron.d/cpu_otm << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/30 * * * * root /usr/bin/autocpu
END
# PERBAIKAN: Hapus wget duplikat
wget -O /usr/bin/autocpu "$repo/install/autocpu.sh" && chmod +x /usr/bin/autocpu

cat >/etc/cron.d/xp_sc <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
1 0 * * * root /usr/bin/expsc
END
set -e 
} &> /dev/null &
loading $! "Loading Start Update Script"
cd /root

# PERBAIKAN: Hapus variabel yang tidak terpakai
# MAX_RETRY=5
# RETRY_COUNT=0
MENU_ZIP="menu.zip"
MENU_DIR="menu"
GITHUB_URL="$repo/menu/menu.zip"

# Cleanup trap
trap 'rm -f "$MENU_ZIP"; rm -rf "$MENU_DIR"' EXIT

echo " 🔄 Mencoba mengunduh menu.zip dari GitHub..."
if wget -q -O "$MENU_ZIP" "$GITHUB_URL"; then
    echo " ✅ Berhasil mengunduh Menu"
else
    echo " ❌ Gagal mengunduh menu.zip dari GitHub."
    exit 1
fi

if [[ -f "$MENU_ZIP" ]]; then
    echo " 🔄 Mengekstrak menu.zip..."
    # Ekstrak ke direktori 'menu'
    7z x "$MENU_ZIP" -o"$MENU_DIR" &> /dev/null

    if [[ $? -eq 0 ]]; then
        echo " ✅ Ekstraksi berhasil, mengatur izin file..."
        chmod +x "$MENU_DIR"/*
        # Pindahkan semua file dari dalam 'menu' ke /usr/bin/
        mv "$MENU_DIR"/* /usr/bin/
        echo " ✅ Menu berhasil Diperbarui!"
    else
        echo " ❌ Gagal mengekstrak menu.zip! File corrupt."
        exit 1
    fi
else
    echo " ❌ Gagal mendapatkan menu.zip."
    exit 1
fi

echo -e " [INFO] Fetching server version..."
serverV=$(curl -sS ${repo}/versi)
echo $serverV > /opt/.ver
rm -- "$0"
echo -e " [INFO] File download and Update completed successfully. Version: $serverV!"
exit
