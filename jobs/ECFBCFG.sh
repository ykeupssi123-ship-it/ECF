#!/bin/bash
# ECFBCFG - ECF_ODOO_BLD_CONFIG - Generation de odoo.conf
#
# Mot de passe maitre (admin_passwd) genere reellement (jamais "admin"
# en dur - c'est le mot de passe qui autorise creer/supprimer une base
# de donnees entiere, la meme discipline que WAZ_INDEXER_ADMIN_PASSWORD
# sur WAZ_ELK_FACTORY s'applique ici). Heredoc QUOTE ('PYEOF') pour que
# bash n'interpole rien dans le mot de passe transmis par variable
# d'environnement - meme discipline que WAZ_014E_INDEXER_CONNECTOR.sh.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

ODOO_ADMIN_PW="$(read_or_generate_secret "$ODOO_ADMIN_PASSWORD_FILE" oui)" || exit 1
PG_ODOO_DB_PASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" || exit 1

SRC_DIR="${ODOO_HOME}/odoo-src"
ADDONS_PATH="${SRC_DIR}/addons,${ODOO_HOME}/custom-addons"

mkdir -p "$(dirname "$ODOO_CONF")" "${ODOO_HOME}/custom-addons" /var/log/odoo
chown "${ODOO_USER}:${ODOO_USER}" "${ODOO_HOME}/custom-addons" /var/log/odoo

ODOO_ADMIN_PW="$ODOO_ADMIN_PW" PG_ODOO_DB_PASSWORD="$PG_ODOO_DB_PASSWORD" \
PG_ODOO_DB_USER="$PG_ODOO_DB_USER" PG_PORT="$PG_PORT" ODOO_PORT="$ODOO_PORT" \
ODOO_LONGPOLLING_PORT="$ODOO_LONGPOLLING_PORT" ODOO_WORKERS="$ODOO_WORKERS" \
ADDONS_PATH="$ADDONS_PATH" ODOO_CONF="$ODOO_CONF" \
python3 << 'PYEOF'
import os
from xml.sax.saxutils import escape

conf_path = os.environ['ODOO_CONF']

content = f"""[options]
admin_passwd = {os.environ['ODOO_ADMIN_PW']}
db_host = 127.0.0.1
db_port = {os.environ['PG_PORT']}
db_user = {os.environ['PG_ODOO_DB_USER']}
db_password = {os.environ['PG_ODOO_DB_PASSWORD']}
addons_path = {os.environ['ADDONS_PATH']}
logfile = /var/log/odoo/odoo.log
log_level = info
http_port = {os.environ['ODOO_PORT']}
longpolling_port = {os.environ['ODOO_LONGPOLLING_PORT']}
workers = {os.environ['ODOO_WORKERS']}
proxy_mode = True
"""

with open(conf_path, 'w') as f:
    f.write(content)
PYEOF

chown root:"${ODOO_USER}" "$ODOO_CONF"
chmod 640 "$ODOO_CONF"

if ! grep -q "^db_user = ${PG_ODOO_DB_USER}$" "$ODOO_CONF"; then
  echo "[ODOO_011] ERREUR : ecriture de ${ODOO_CONF} echouee (verification post-ecriture)." >&2
  exit 1
fi

echo "[ODOO_011] OK (${ODOO_CONF} genere, droits 640 root:${ODOO_USER})."
exit 0
