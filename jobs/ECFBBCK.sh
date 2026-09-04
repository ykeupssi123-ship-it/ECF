#!/bin/bash
# ECFBBCK - ECF_ODOO_BLD_BACKUP - Sauvegarde (base +
# filestore) - anticipe des la fondation, meme lecon deja tiree sur
# ANKRR_ENGINE : ne jamais laisser la sauvegarde pour plus tard.
set -uo pipefail
source "$VARS_FILE"

mkdir -p "$BACKUP_DIR"

cat > /usr/local/sbin/odoo-backup.sh << EOF
#!/bin/bash
# Sauvegarde generee par ODOO_018_BACKUP_SCRIPT.sh - ne pas editer a la main.
# Sauvegarde la base PostgreSQL ET le filestore (pieces jointes, images
# produits, PDF generes) - une sauvegarde de la seule base est
# incomplete pour Odoo, contrairement a beaucoup d'autres applications.
set -uo pipefail
STAMP=\$(date +%Y%m%d_%H%M%S)
DEST="${BACKUP_DIR}/\${STAMP}"
mkdir -p "\$DEST"

PGPASSWORD="\$(cat '${PG_ODOO_DB_PASSWORD_FILE}')" pg_dump -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -Fc "${PG_ODOO_DB_NAME}" > "\${DEST}/${PG_ODOO_DB_NAME}.dump"

FILESTORE="${ODOO_HOME}/.local/share/Odoo/filestore/${PG_ODOO_DB_NAME}"
if [ -d "\$FILESTORE" ]; then
  tar -czf "\${DEST}/filestore.tar.gz" -C "\$(dirname "\$FILESTORE")" "\$(basename "\$FILESTORE")"
fi

find "${BACKUP_DIR}" -maxdepth 1 -mtime "+${BACKUP_RETENTION_DAYS}" -type d -exec rm -rf {} \; 2>/dev/null || true

logger -t odoo-backup "Sauvegarde terminee : \${DEST}"
EOF
chmod 750 /usr/local/sbin/odoo-backup.sh

cat > /etc/systemd/system/odoo-backup.service << 'EOF'
[Unit]
Description=Sauvegarde quotidienne Odoo (base + filestore)
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/odoo-backup.sh
EOF

cat > /etc/systemd/system/odoo-backup.timer << 'EOF'
[Unit]
Description=Declenche la sauvegarde Odoo une fois par jour
[Timer]
OnCalendar=*-*-* 02:00:00
RandomizedDelaySec=300
Persistent=true
[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now odoo-backup.timer

echo "[ODOO_018] Premiere sauvegarde reelle de verification..."
/usr/local/sbin/odoo-backup.sh
LATEST=$(ls -td "${BACKUP_DIR}"/*/ 2>/dev/null | head -1)
if [ -z "$LATEST" ] || [ ! -f "${LATEST}${PG_ODOO_DB_NAME}.dump" ]; then
  echo "[ODOO_018] ERREUR : aucune sauvegarde reelle produite - le script echoue silencieusement." >&2
  exit 1
fi

echo "[ODOO_018] OK (sauvegarde reelle verifiee dans ${LATEST}, timer quotidien 02h00 actif)."
exit 0
