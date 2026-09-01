#!/bin/bash
# ODOO_016_SMTP_RELAY - WEF_ODOO_BLD_SMTP - Relais SMTP sortant local
# (devis/factures par e-mail, notifications - fait partie de
# l'ecosysteme immediat d'Odoo). Postfix en mode local simple pour la
# demo - jamais un vrai relais de production tant que ce n'est pas
# demande explicitement (voir SMTP_RELAY_MODE dans vars.conf).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

if ! rpm -q postfix &>/dev/null; then
  echo "[ODOO_016] Installation de postfix..."
  dnf install -y postfix
fi

postconf -e "inet_interfaces = loopback-only"
postconf -e "myhostname = ${ERP_DASHBOARD_FQDN}"
postconf -e "mydomain = ${DNS_DOMAIN}"

systemctl enable postfix 2>/dev/null || true
systemctl restart postfix 2>/dev/null || true
if ! wait_for_service_active postfix 30 5; then
  echo "[ODOO_016] ERREUR : postfix n'a pas demarre." >&2
  exit 1
fi

echo "[ODOO_016] Verification reelle : le port ${SMTP_RELAY_PORT} (loopback) repond..."
if ! nc -z -w3 127.0.0.1 "${SMTP_RELAY_PORT}"; then
  echo "[ODOO_016] ERREUR : port SMTP local injoignable apres demarrage." >&2
  exit 1
fi

echo "[ODOO_016] OK (Postfix pret pour la configuration du serveur sortant dans Odoo, Parametres > Technique > Serveurs sortants)."
exit 0
