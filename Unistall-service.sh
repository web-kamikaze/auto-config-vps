#!/usr/bin/env bash
# smart-uninstall-pro.sh
# Script interaktif: scan, pilih, dan uninstall layanan populer di VPS

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Harap jalankan sebagai root (sudo)."
  exit 1
fi

# Deteksi package manager
if command -v apt-get >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v yum >/dev/null 2>&1; then
  PM="yum"
else
  echo "Tidak menemukan package manager apt/dnf/yum."
  exit 1
fi

echo "=== AUTO SCAN LAYANAN YANG BERJALAN ==="
echo

# Ambil semua service aktif
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}' | sed 's/.service//')

# Daftar layanan umum di VPS
COMMON_SERVICES=(
  # Web server
  nginx apache2 httpd lighttpd caddy
  # PHP
  php php-fpm php7.4-fpm php8.0-fpm php8.1-fpm
  # Database
  mysql mariadb postgresql mongodb redis memcached
  # Proxy / VPN
  squid3 squid3 squid tinyproxy shadowsocks v2ray xray trojan trojan-go openvpn wireguard pptpd l2tp strongswan
  # Web panels
  hestia vesta cyberpanel aaPanel webmin ispconfig
  # Email
  postfix dovecot exim4 courier
  # Security / Firewall
  ufw firewalld fail2ban
  # Cache / Queue
  rabbitmq-server mosquitto
  # Docker & container
  docker docker.io containerd podman
  # Tools umum
  certbot snapd cron rsync supervisor netdata prometheus grafana
  # Speedtest / monitoring
  speedtest speedtestd node_exporter
  # Reverse proxy
  haproxy envoy
)

FOUND_SERVICES=()
for svc in "${COMMON_SERVICES[@]}"; do
  if echo "$ACTIVE_SERVICES" | grep -qw "$svc"; then
    FOUND_SERVICES+=("$svc")
  fi
done

if [ ${#FOUND_SERVICES[@]} -eq 0 ]; then
  echo "Tidak ada layanan populer terdeteksi berjalan."
  echo
  echo "Daftar semua service aktif (sebagian):"
  echo "$ACTIVE_SERVICES" | head -n 20
  exit 0
fi

echo "Layanan aktif terdeteksi:"
i=1
for s in "${FOUND_SERVICES[@]}"; do
  echo "  [$i] $s"
  ((i++))
done
echo
read -p "Masukkan nomor layanan yang ingin dihapus (pisahkan dengan spasi, mis: 1 3 5): " selection

SELECTED=()
for n in $selection; do
  idx=$((n-1))
  if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#FOUND_SERVICES[@]}" ]; then
    SELECTED+=("${FOUND_SERVICES[$idx]}")
  fi
done

if [ ${#SELECTED[@]} -eq 0 ]; then
  echo "Tidak ada layanan yang dipilih."
  exit 0
fi

echo
echo "Akan dihapus: ${SELECTED[*]}"
read -p "Ketik 'YES' untuk konfirmasi uninstall: " confirm
if [ "$confirm" != "YES" ]; then
  echo "Dibatalkan."
  exit 0
fi

echo
for svc in "${SELECTED[@]}"; do
  echo ">>> Menghapus layanan: $svc"

  # Stop dan disable
  systemctl stop "$svc" 2>/dev/null || true
  systemctl disable "$svc" 2>/dev/null || true
  systemctl mask "$svc" 2>/dev/null || true

  # Uninstall paket
  if [ "$PM" = "apt" ]; then
    apt-get purge -y "$svc" || true
    apt-get autoremove -y || true
  elif [ "$PM" = "dnf" ]; then
    dnf remove -y "$svc" || true
  elif [ "$PM" = "yum" ]; then
    yum remove -y "$svc" || true
  fi

  # Bersihkan direktori umum
  case "$svc" in
    nginx) rm -rf /etc/nginx /var/www /var/log/nginx ;;
    apache2|httpd) rm -rf /etc/apache2 /var/www /var/log/apache2 ;;
    php*|php-fpm) rm -rf /etc/php /var/lib/php /var/log/php* ;;
    mysql|mariadb) rm -rf /etc/mysql /var/lib/mysql /var/log/mysql ;;
    postgresql) rm -rf /etc/postgresql /var/lib/postgresql ;;
    redis) rm -rf /etc/redis /var/log/redis* ;;
    memcached) rm -rf /etc/memcached /var/log/memcached ;;
    docker|containerd|podman) rm -rf /etc/docker /var/lib/docker ;;
    v2ray|xray|trojan|trojan-go) rm -rf /etc/v2ray /usr/local/etc/v2ray /usr/local/etc/xray /etc/trojan* ;;
    openvpn|wireguard) rm -rf /etc/openvpn /etc/wireguard ;;
    ufw) ufw --force reset ;;
    firewalld) systemctl stop firewalld; systemctl disable firewalld ;;
    fail2ban) rm -rf /etc/fail2ban ;;
    certbot) rm -rf /etc/letsencrypt /var/lib/letsencrypt ;;
    grafana) rm -rf /etc/grafana /var/lib/grafana ;;
    prometheus) rm -rf /etc/prometheus /var/lib/prometheus ;;
    haproxy) rm -rf /etc/haproxy /var/log/haproxy ;;
    *) ;;
  esac

  echo "✓ $svc berhasil dihapus."
  echo
done

systemctl daemon-reload
echo "=== SELESAI ==="
