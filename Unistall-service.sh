#!/usr/bin/env bash
# =========================================================
#  Name: Uninstall Service Script (Smart VPS Cleaner)
#  Author: Dodi Dam (Web-Kamikaze)
#  Repo: https://github.com/web-kamikaze/auto-config-vps
#  Version: 2.0 (2025-10)
#  Description: Auto-scan, select, and uninstall services from VPS
#  Supported OS: Debian, Ubuntu, CentOS, Rocky, AlmaLinux, Fedora
# =========================================================

set -e

LOG_FILE="/root/uninstall-log.txt"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "===== Log mulai: $(date) ====="

# -----------------------------
#  Detect OS
# -----------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    OS=$(uname -s)
    VER=$(uname -r)
fi

echo "Detected OS: $OS $VER"
echo

# -----------------------------
#  Package manager setup
# -----------------------------
if command -v apt-get >/dev/null 2>&1; then
    PKG_REMOVE="apt-get remove --purge -y"
    PKG_CLEAN="apt-get autoremove -y && apt-get clean"
elif command -v dnf >/dev/null 2>&1; then
    PKG_REMOVE="dnf remove -y"
    PKG_CLEAN="dnf autoremove -y && dnf clean all"
elif command -v yum >/dev/null 2>&1; then
    PKG_REMOVE="yum remove -y"
    PKG_CLEAN="yum autoremove -y && yum clean all"
else
    echo "❌ Tidak dapat mendeteksi package manager (apt/dnf/yum)."
    exit 1
fi

# -----------------------------
#  Daftar layanan umum
# -----------------------------
SERVICES=(
    nginx
    apache2
    httpd
    php
    php-fpm
    mariadb
    mysql
    postgresql
    redis
    memcached
    docker
    docker-compose
    fail2ban
    ufw
    firewalld
    netdata
    nodejs
    npm
    python3
    pip
    certbot
    v2ray
    xray
    trojan
    openvpn
    wireguard
    shadowsocks
    speedtest
    curl
    vsftpd
    proftpd
)

# -----------------------------
#  Help
# -----------------------------
if [[ "$1" == "--help" ]]; then
    echo "Usage: bash Unistall-service.sh [--auto service1 service2 ...]"
    echo "       Uninstall selected services from VPS safely."
    echo "Example: bash Unistall-service.sh --auto nginx php-fpm mysql"
    exit 0
fi

# -----------------------------
#  Auto mode
# -----------------------------
AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
    shift
    SELECTED=("$@")
fi

# -----------------------------
#  Deteksi layanan aktif
# -----------------------------
echo "🔍 Memindai layanan aktif..."
RUNNING=()
for s in "${SERVICES[@]}"; do
    if systemctl list-units --type=service --state=running | grep -q "$s"; then
        RUNNING+=("$s")
    fi
done

if [ ${#RUNNING[@]} -eq 0 ]; then
    echo "✅ Tidak ada layanan aktif dari daftar yang terdeteksi."
    exit 0
fi

echo "Ditemukan layanan aktif:"
printf ' - %s\n' "${RUNNING[@]}"
echo

# -----------------------------
#  Menu interaktif (whiptail)
# -----------------------------
if [ "$AUTO_MODE" = false ]; then
    if command -v whiptail >/dev/null 2>&1; then
        OPTIONS=()
        for s in "${RUNNING[@]}"; do
            OPTIONS+=("$s" "$s service" OFF)
        done
        CHOSEN=$(whiptail --title "Smart VPS Cleaner" \
            --checklist "Pilih layanan yang ingin dihapus (Spasi = pilih)" 25 70 15 \
            "${OPTIONS[@]}" 3>&1 1>&2 2>&3)
        SELECTED=($(echo "$CHOSEN" | tr -d '"'))
    else
        echo "Masukkan layanan yang ingin dihapus (pisahkan dengan spasi):"
        read -rp "> " -a SELECTED
    fi
fi

# -----------------------------
#  Uninstall proses
# -----------------------------
if [ ${#SELECTED[@]} -eq 0 ]; then
    echo "❌ Tidak ada layanan yang dipilih."
    exit 0
fi

echo "🚮 Menghapus layanan terpilih: ${SELECTED[*]}"
for s in "${SELECTED[@]}"; do
    echo "--------------------------------------"
    echo "🔧 Uninstall: $s"
    systemctl stop "$s" 2>/dev/null || true
    eval "$PKG_REMOVE $s" || echo "⚠️  Gagal menghapus $s (mungkin tidak terpasang)"
done

echo
echo "🧹 Membersihkan paket sisa..."
eval "$PKG_CLEAN"

echo "✅ Proses selesai. Log tersimpan di: $LOG_FILE"
echo "===== Selesai: $(date) ====="
