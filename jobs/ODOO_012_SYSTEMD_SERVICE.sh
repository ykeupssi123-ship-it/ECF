#!/bin/bash
# ODOO_012_SYSTEMD_SERVICE - WEF_ODOO_BLD_SYSTEMD - Service systemd
# (Odoo tourne comme un vrai service supervise, jamais un processus
# lance a la main dans un terminal qui meurt a la deconnexion)
set -uo pipefail
source "$VARS_FILE"

SRC_DIR="${ODOO_HOME}/odoo-src"
VENV_DIR="${ODOO_HOME}/venv"
UNIT_FILE="/etc/systemd/system/odoo.service"

cat > "$UNIT_FILE" << EOF
[Unit]
Description=Odoo ${ODOO_VERSION} (ERP_CRM_FACTORY)
Requires=postgresql-${PG_VERSION}.service
After=network.target postgresql-${PG_VERSION}.service

[Service]
Type=simple
User=${ODOO_USER}
Group=${ODOO_USER}
ExecStart=${VENV_DIR}/bin/python3 ${SRC_DIR}/odoo-bin -c ${ODOO_CONF}
Restart=on-failure
RestartSec=5
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable odoo 2>/dev/null || true

if ! systemctl cat odoo >/dev/null 2>&1; then
  echo "[ODOO_012] ERREUR : unite systemd 'odoo' introuvable apres creation." >&2
  exit 1
fi

echo "[ODOO_012] OK."
exit 0
