#!/usr/bin/env bash
set -Eeuo pipefail

# Solicita y configura un certificado Let's Encrypt en Apache mediante Certbot.
# Ejecutar desde el directorio del repositorio:
#   sudo bash scripts/setup_letsencrypt_certificate.sh
#
# Antes: editar scripts/.env, comprobar DNS y permitir el puerto 80 en AWS.

if [[ "${EUID}" -ne 0 ]]; then
  echo "Ejecuta este script con sudo: sudo bash $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "No se encuentra ${ENV_FILE}." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

: "${DOMAIN:?Debes definir DOMAIN en scripts/.env}"
: "${EMAIL:?Debes definir EMAIL en scripts/.env}"

if [[ "${EMAIL}" == "CAMBIAR_POR_TU_CORREO" || "${EMAIL}" != *"@"* ]]; then
  echo "Edita EMAIL en scripts/.env y escribe tu correo real." >&2
  exit 1
fi

if [[ ! "${DOMAIN}" =~ ^[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$ ]]; then
  echo "DOMAIN no parece ser un nombre DNS válido: ${DOMAIN}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "[1/5] Comprobando Apache..."
if ! systemctl is-active --quiet apache2; then
  echo "Apache no está activo. Comprueba WordPress por HTTP antes de continuar." >&2
  exit 1
fi
apache2ctl configtest

echo "[2/5] Comprobando resolución DNS de ${DOMAIN}..."
if ! getent ahostsv4 "${DOMAIN}" >/dev/null; then
  echo "El dominio no resuelve por IPv4. Corrige el DNS antes de solicitar el certificado." >&2
  exit 1
fi
getent ahostsv4 "${DOMAIN}" | head -n 1

echo "[3/5] Instalando snapd si hace falta..."
apt-get update
apt-get install -y snapd

echo "[4/5] Instalando Certbot desde Snap si hace falta..."
if ! snap list core >/dev/null 2>&1; then
  snap install core
fi
snap refresh core
if ! snap list certbot >/dev/null 2>&1; then
  apt-get remove -y certbot >/dev/null 2>&1 || true
  snap install --classic certbot
fi
ln -sf /snap/bin/certbot /usr/bin/certbot

echo "[5/5] Solicitando certificado para ${DOMAIN}..."
echo "Asegúrate de que el puerto TCP 80 es accesible desde Internet."
certbot --apache --non-interactive --agree-tos --email "${EMAIL}" --no-eff-email -d "${DOMAIN}" --redirect

echo
echo "Certbot ha finalizado. Comprueba con: certbot certificates"
echo "No se han cambiado automáticamente WP_HOME/WP_SITEURL; actualízalos tras verificar el certificado."
