#!/bin/bash
# SUSR - ECF_ODOO_BLD_SYSUSER - Compte systeme dedie
#
# Meme discipline que WEF (un compte systeme par service, jamais root) :
# Odoo tourne sous son propre utilisateur, jamais root, jamais un compte
# partage avec un autre service.
set -uo pipefail
source "$VARS_FILE"

if id "${ODOO_USER}" &>/dev/null; then
  echo "[ODOO_002] Utilisateur ${ODOO_USER} deja present, ignore."
else
  echo "[ODOO_002] Creation de l'utilisateur systeme ${ODOO_USER}..."
  useradd -r -m -U -d "${ODOO_HOME}" -s /bin/bash "${ODOO_USER}"
fi

mkdir -p "${ODOO_HOME}"
chown "${ODOO_USER}:${ODOO_USER}" "${ODOO_HOME}"

if ! id "${ODOO_USER}" &>/dev/null; then
  echo "[ODOO_002] ERREUR : utilisateur ${ODOO_USER} toujours absent apres creation." >&2
  exit 1
fi

echo "[ODOO_002] OK."
exit 0
