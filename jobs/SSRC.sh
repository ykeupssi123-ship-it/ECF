#!/bin/bash
# SSRC - ECF_ODOO_BLD_SRCCLONE - Recuperation du code
# source d'Odoo (edition Community, LGPL - depot officiel verifie :
# https://github.com/odoo/odoo, branche 19.0)
set -uo pipefail
source "$VARS_FILE"

SRC_DIR="${ODOO_HOME}/odoo-src"

if [ -d "${SRC_DIR}/.git" ]; then
  echo "[ODOO_009] Code source deja present dans ${SRC_DIR}, ignore."
  echo "[ODOO_009] OK."
  exit 0
fi

# CORRIGE le 2026-09-01 (echec reel, voir docs/JOURNAL_TECHNIQUE.md) :
# echec observe "Empty reply from server" sur ce lien VM->GitHub - repete
# manuellement juste apres et confirme transitoire (connectivite HTTP 200
# immediate, second clone quasi complet). A la difference des incidents
# precedents (URL fausse, paquet redondant), il n'y a ici aucun defaut de
# script a corriger sur le fond - seulement l'absence de resilience face a
# une coupure reseau ponctuelle sur un clone de ~48000 fichiers. Boucle de
# nouvelle tentative ajoutee (3 essais, nettoyage du repertoire partiel
# entre chaque essai) plutot qu'un simple "reessayez a la main" : ce job
# sera rejoue de nombreuses fois au fil du projet, jamais suppose fiable a
# 100% sur un seul essai pour un transfert de cette taille.
echo "[ODOO_009] Clonage d'Odoo ${ODOO_VERSION} (edition Community, LGPL) depuis le depot officiel..."
CLONE_OK=0
for essai in 1 2 3; do
  rm -rf "${SRC_DIR}"
  if sudo -u "${ODOO_USER}" git clone --depth 1 --branch "${ODOO_VERSION}" https://github.com/odoo/odoo.git "${SRC_DIR}"; then
    CLONE_OK=1
    break
  fi
  echo "[ODOO_009] Essai ${essai}/3 echoue, nouvelle tentative dans 10s..." >&2
  sleep 10
done

if [ "$CLONE_OK" -ne 1 ] || [ ! -f "${SRC_DIR}/odoo-bin" ]; then
  echo "[ODOO_009] ERREUR : odoo-bin introuvable apres 3 tentatives de clonage - le depot n'a pas ete recupere correctement." >&2
  exit 1
fi

echo "[ODOO_009] OK ($(cd "$SRC_DIR" && git log -1 --format='%h %s'))."
exit 0
