#!/bin/bash

source /usr/local/bin/ui.sh
clear

lane_atas
tengah "CONFIGURE RSYSLOG" "${BRED}${WHITE}" 1
lane_bawah

DROPBEAR_LOG_CONF="/etc/rsyslog.d/30-dropbear.conf"

if [ -f "$DROPBEAR_LOG_CONF" ]; then
  echo -e "${CYAN}Konfigurasi log Dropbear sudah ada di $DROPBEAR_LOG_CONF, melewati..${RESET}"
else
  cat > "$DROPBEAR_LOG_CONF" <<EOF
# Konfigurasi kustom oleh installer-os
# Mengarahkan log 'dropbear' ke 'auth.log'
if \$programname == "dropbear" then /var/log/auth.log
# Hentikan pemrosesan di sini agar tidak masuk ke syslog/messages
& stop
EOF
  
  systemctl restart rsyslog
fi

# --- Bagian 2: Pengaturan Izin Log ---

# Logika ini sudah bagus dan dipertahankan.
LOG_FILES=(
  "/var/log/auth.log"
  "/var/log/kern.log"
  "/var/log/mail.log"
  "/var/log/user.log"
  "/var/log/cron.log"
)

# Fungsi untuk mengatur izin
set_permissions() {
  for log_file in "${LOG_FILES[@]}"; do
    if [[ -f "$log_file" ]]; then
      echo -e "${CYAN}Memperbarui izin/kepemilikan untuk $log_file..${RESET}"
      chmod 640 "$log_file"
      chown syslog:adm "$log_file"  
    else
      echo -e "${CYAN}$log_file tidak ditemukan, melewati..${RESET}"
    fi
  done
}

# Jalankan fungsi pengaturan izin
set_permissions

rm -f "$0"
