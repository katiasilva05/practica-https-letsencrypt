#!/usr/bin/env bash
set -Eeuo pipefail

# Instalación básica y no interactiva de Apache, PHP y MariaDB en Ubuntu/Debian.
# Ejecutar: sudo bash scripts/install_lamp.sh

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/4] Actualizando índices de paquetes..."
apt-get update

echo "[2/4] Instalando Apache, PHP y MariaDB..."
apt-get install -y apache2 mariadb-server php libapache2-mod-php php-mysql

echo "[3/4] Habilitando e iniciando servicios..."
systemctl enable --now apache2
systemctl enable --now mariadb

echo "[4/4] Comprobando Apache..."
apache2ctl configtest
systemctl reload apache2

echo
echo "Instalación básica LAMP terminada."
echo "Apache:  $(systemctl is-active apache2)"
echo "MariaDB: $(systemctl is-active mariadb)"
php --version | head -n 1
echo "Nota: este script instala los servicios; no crea bases de datos ni usuarios de WordPress."
