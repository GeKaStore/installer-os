#!/bin/bash

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
tengah() {
  TEKS="$1"
  WARNA="$2"
  POSITION=$3
  PANJANG_KONTEN=42
  
  LEBAR_TEKS=$(echo -n "$TEKS" | wc -c)
  
  PADDING_TOTAL=$(( PANJANG_KONTEN - LEBAR_TEKS ))
  PADDING_KIRI=$(( PADDING_TOTAL / 2 ))
  PADDING_KANAN=$(( PADDING_TOTAL - PADDING_KIRI ))
  
  if [ $LEBAR_TEKS -gt $PANJANG_KONTEN ]; then
    PADDING_KIRI=0
    PADDING_KANAN=0
    TEKS="${TEKS:0:42}"
    echo "Peringatan: Teks dipotong karena melebihi 42 karakter!"
  fi
  
  SPASI_KIRI=$(printf "%*s" $PADDING_KIRI "")
  SPASI_KANAN=$(printf "%*s" $PADDING_KANAN "")
  
  tput cup $POSITION 0
  echo -n " "
  echo -e -n "$WARNA$SPASI_KIRI$TEKS$SPASI_KANAN\033[0m"
  echo -e " "
}

function lane_atas() {
  echo -e "${CYAN}┌──────────────────────────────────────────┐${RESET}"
}
function lane_bawah() {
  echo -e "${CYAN}└──────────────────────────────────────────┘${RESET}"
}