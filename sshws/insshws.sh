#!/bin/bash
# Dijalankan oleh Install.sh

clear

source /usr/local/bin/ui.sh

# Definisikan variabel agar mudah diubah
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"
# PERBAIKAN: Typo 'handeling' -> 'handling'
file_path="/etc/handling"

# Cek file /etc/handling
if [ ! -f "$file_path" ]; then
    # Jika file tidak ada, buat file dan isi.
    # PERBAIKAN: Hapus 'sudo' (skrip sudah root) dan 'tee' yang tidak perlu
    echo -e "WUZZSTORE\nYellow" > "$file_path"
    
elif [ ! -s "$file_path" ]; then
    # Jika file ada tetapi kosong, isi.
    # PERBAIKAN: Typo 'Noice' -> 'Nice'
    echo -e "WUZZSTORE\nYellow" > "$file_path"
fi
# Jika file ada dan berisi data, tidak perlu 'else', biarkan saja.

# --- PERBAIKAN: Pindahkan lokasi file agar Sesuai Standar Linux ---
# /usr/bin HANYA untuk biner
# /etc HANYA untuk konfigurasi
ws_bin="/usr/bin/ws"
ws_conf="/etc/ws.conf" # Nama file config yang lebih deskriptif

lane_atas
tengah "CONFIGURE SSH WS" "${BRED}${WHITE}" 1
wget -O "$ws_bin" "${REPO}sshws/ws"
wget -O "$ws_conf" "${REPO}sshws/config.conf"

# Beri izin eksekusi HANYA pada biner
chmod +x "$ws_bin"

# Buat file layanan systemd
# PERBAIKAN: Perbarui 'ExecStart' untuk menunjuk ke file config yang benar
cat > /etc/systemd/system/ws.service << END
[Unit]
Description=WebSocket Service (E-Pro V1 By Beby)
Documentation=https://github.com/Beby
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=${ws_bin} -f ${ws_conf}
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=65535
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target

END

# Muat ulang, aktifkan, dan restart layanan
systemctl daemon-reload
systemctl enable ws.service
# PERBAIKAN: Hapus 'systemctl start', 'restart' sudah mencakup semuanya.
systemctl restart ws.service
