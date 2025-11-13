#!/bin/bash
MYIP=$(curl -sS ipv4.icanhazip.com)
file_path="/etc/handeling"
REPO="https://raw.githubusercontent.com/GeKaStore/installer-os/main/"
# Cek apakah file ada
if [ ! -f "$file_path" ]; then
    # Jika file tidak ada, buat file dan isi dengan dua baris
    echo -e "WUZZSTORE\nYellow" | sudo tee "$file_path" > /dev/null
    echo "File '$file_path' berhasil dibuat."
else
    # Jika file ada, cek apakah isinya kosong
    if [ ! -s "$file_path" ]; then
        # Jika file ada tetapi kosong, isi dengan dua baris
        echo -e "Noice Server Connected\nGreen" | sudo tee "$file_path" > /dev/null
        echo "File '$file_path' kosong dan telah diisi."
    else
        # Jika file ada dan berisi data, tidak lakukan apapun
        echo "File '$file_path' sudah ada dan berisi data."
    fi
fi
wget -O /usr/bin/ws "${REPO}sshws/ws"
wget -O /usr/bin/config.conf "${REPO}sshws/config.conf"
chmod +x /usr/bin/ws
cat > /etc/systemd/system/ws.service << END
[Unit]
Description=WebSocket E-Pro V1 By Beby
Documentation=https://github.com/Beby
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/ws -f /usr/bin/config.conf
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=65535
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target

END

systemctl daemon-reload
systemctl enable ws.service
systemctl start ws.service
systemctl restart ws.service