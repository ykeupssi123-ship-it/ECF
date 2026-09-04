#!/bin/bash
# ECFBDNS - ECF_ODOO_BLD_DNSZONE - Resolution interne pour
# l'URL de demo (meme principe que DNS_002_ZONE.sh sur WAZ_ELK_FACTORY)
#
# Portee volontairement minimale : ne fait autorite que sur le FQDN de
# ce projet, relaie tout le reste vers le resolveur habituel - un poste
# qui utilise ce DNS en secondaire garde une resolution Internet normale.
set -uo pipefail
source "$VARS_FILE"

if ! rpm -q dnsmasq &>/dev/null; then
  echo "[ODOO_017] Installation de dnsmasq..."
  dnf install -y dnsmasq
fi

ZONE_FILE="/etc/dnsmasq.d/erp-zone.conf"
cat > "$ZONE_FILE" << EOF
# Regenere entierement par ODOO_017_DNS_ZONE.sh - ne pas editer a la main.
listen-address=127.0.0.1,${FACTORY_HOST_IP}
bind-interfaces
domain=${DNS_DOMAIN}
expand-hosts
address=/${ERP_DASHBOARD_FQDN}/${FACTORY_HOST_IP}
EOF
chmod 644 "$ZONE_FILE"

if ! dnsmasq --test --conf-file=/etc/dnsmasq.conf 2>&1 | grep -q "syntax check OK"; then
  echo "[ODOO_017] ERREUR : dnsmasq rejette la configuration." >&2
  dnsmasq --test --conf-file=/etc/dnsmasq.conf >&2 2>&1 || true
  exit 1
fi

systemctl enable dnsmasq 2>/dev/null || true
systemctl restart dnsmasq 2>/dev/null || true
if ! systemctl is-active --quiet dnsmasq; then
  echo "[ODOO_017] ERREUR : dnsmasq n'a pas demarre." >&2
  exit 1
fi

if systemctl is-active --quiet firewalld; then
  firewall-cmd --permanent --add-service=dns >/dev/null
  firewall-cmd --reload >/dev/null
fi

echo "[ODOO_017] OK (${ERP_DASHBOARD_FQDN} -> ${FACTORY_HOST_IP})."
echo "[ODOO_017] RAPPEL : sur le poste qui fera la demo, ajoutez ${FACTORY_HOST_IP} en DNS secondaire de l'interface reseau (meme procedure que documentee pour WAZ_ELK_FACTORY, Set-DnsClientServerAddress) - ou plus simple, ajoutez une ligne dans le fichier hosts local : ${FACTORY_HOST_IP} ${ERP_DASHBOARD_FQDN}"
exit 0
