#!/bin/bash

# ==========================================================
# Pustaka UI (ui.sh)
# Menyediakan variabel warna dan fungsi untuk menggambar box
# ==========================================================

# WARNA FONT TPUT
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
GRAY=$(tput setaf 8)
BR=$(tput setaf 9)
BG=$(tput setaf 10)
BY=$(tput setaf 11)
BB=$(tput setaf 12)
BM=$(tput setaf 13)
BC=$(tput setaf 14)
BW=$(tput setaf 15)

# WARNA BACKGROUND TPUT
BBLACK=$(tput setab 0)
BRED=$(tput setab 1)
BGREEN=$(tput setab 2)
BYELLOW=$(tput setab 3)
BBLUE=$(tput setab 4)
BMAGENTA=$(tput setab 5)
BCYAN=$(tput setab 6)
BWHITE=$(tput setab 7)
BGRAY=$(tput setab 8)
BBR=$(tput setab 9)
BBG=$(tput setab 10)
BBY=$(tput setab 11)
BBB=$(tput setab 12)
BBM=$(tput setab 13)
BBC=$(tput setab 14)
BBW=$(tput setab 15)

# PEMBANTU WARNA TPUT
RESET=$(tput sgr0)
BOLD=$(tput bold)

# TEKS DITENGAN
# Fungsi ini mencetak teks di tengah dalam kotak 42 karakter
# dan memindahkannya ke posisi baris ($POSITION) tertentu.
tengah() {
  TEKS="$1"
  WARNA="$2"
  POSITION=$3
  PANJANG_KONTEN=42 # Lebar total kotak (sesuai 'lane_atas')
  
  LEBAR_TEKS=$(echo -n "$TEKS" | wc -c)
  
  PADDING_TOTAL=$(( PANJANG_KONTEN - LEBAR_TEKS ))
  PADDING_KIRI=$(( PADDING_TOTAL / 2 ))
  PADDING_KANAN=$(( PADDING_TOTAL - PADDING_KIRI ))
  
  # Jika teks terlalu panjang, potong
  if [ $LEBAR_TEKS -gt $PANJANG_KONTEN ]; then
    PADDING_KIRI=0
    PADDING_KANAN=0
    TEKS="${TEKS:0:42}"
    # Peringatan ini mungkin mengganggu UI, bisa dikomentari jika perlu
    echo "Peringatan: Teks dipotong karena melebihi 42 karakter!"
  fi
  
  SPASI_KIRI=$(printf "%*s" $PADDING_KIRI "")
  SPASI_KANAN=$(printf "%*s" $PADDING_KANAN "")
  
  # Pindahkan kursor ke baris $POSITION, kolom 0
  tput cup $POSITION 0
  
  # Cetak baris dengan padding
  echo -n " " # Margin kiri 1 spasi
  # PERBAIKAN: Gunakan $RESET, bukan hardcode '\033[0m'
  echo -e -n "$WARNA$SPASI_KIRI$TEKS$SPASI_KANAN$RESET"
  echo -e " " # Margin kanan 1 spasi
}

# Fungsi untuk garis atas kotak
function lane_atas() {
  echo -e "${CYAN}┌──────────────────────────────────────────┐${RESET}"
}

# Fungsi untuk garis bawah kotak
function lane_bawah() {
  echo -e "${CYAN}└──────────────────────────────────────────┘${RESET}"
  echo -e ""
}

# --- FUNGSI DOWNLOADER AMAN ---
# Penggunaan: run_sub_script "install/ssh-vpn.sh"
function run_sub_script() {
    clear
    local SCRIPT_PATH=$1
    local SCRIPT_URL="${REPO}/${SCRIPT_PATH}"
    local SCRIPT_NAME=$(basename "$SCRIPT_PATH")
    local TEMP_FILE="/tmp/${SCRIPT_NAME}_$RANDOM.sh"
    
    # Unduh ke file sementara
    wget -O "$TEMP_FILE" "$SCRIPT_URL"
    
    # Cek apakah download berhasil dan file tidak kosong
    if [ ! -s "$TEMP_FILE" ]; then
        echo "FATAL: Gagal mengunduh '$SCRIPT_URL'. Instalasi dihentikan."
        rm -f "$TEMP_FILE"
        exit 1
    fi
    
    # Beri izin eksekusi dan jalankan
    chmod +x "$TEMP_FILE"
    bash "$TEMP_FILE"
    
    # Bersihkan file sementara
    rm -f "$TEMP_FILE"
    clear
}
