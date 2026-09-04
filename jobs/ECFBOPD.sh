#!/bin/bash
# ECFBOPD - ECF_SYS_BLD_OPDIRS
# Construit l'arborescence operationnelle ($ECFOP) : un espace dedie
# par module (memes codes courts que la colonne SERVICE de
# jobs_table.csv), avec 3 sous-dossiers : rcv (fichiers recus/a
# traiter), snd (fichiers produits/a exporter), arc (archive).
#
# AJOUTE LE 2026-09-04 (demande explicite utilisateur, voir
# docs/JOURNAL_TECHNIQUE.md - inspire d'une pratique reelle Control-M/
# SGABS : SM2/RCV, SM2/SND_BNK...). VOLONTAIREMENT LIMITE a cette
# structure simple (rcv/snd/arc par module, tout en minuscule pour ne
# pas gener la saisie repetee) - PAS de zone tampon/entite externe
# (l'equivalent du CFT/SNAP de la SG) : ce niveau suppose de vraies
# entites externes avec qui echanger, qui n'existent pas encore sur
# cette version generique d'ECF - ce sera construit plus tard, une fois
# un client/filiale reel defini (meme principe que le report du
# trigramme filiale, voir docs/JOURNAL_TECHNIQUE.md). Inventer cette
# couche maintenant serait de la conformite simulee, contraire au
# principe directeur du projet (README.md : "jamais suppose, toujours
# verifie").
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"

# Codes courts des 34 modules (identiques a la colonne SERVICE de
# jobs_table.csv - jamais une seconde liste maintenue a la main).
MODULE_CODES="$(awk -F',' 'NR>1 && $9!="SYS" && $9!~/^ILL_/ {if (!seen[$9]++) print tolower($9)}' "$PROJECT_ROOT/jobs_table.csv")"

echo "[SOPD] Construction de l'arborescence operationnelle sous ${OPERATIONS_DIR}..."
mkdir -p "$OPERATIONS_DIR"
COUNT=0
while IFS= read -r code; do
  [ -z "$code" ] && continue
  for sub in rcv snd arc; do
    mkdir -p "${OPERATIONS_DIR}/${code}/${sub}"
  done
  COUNT=$((COUNT+1))
done <<< "$MODULE_CODES"

echo "[SOPD] Alignement des droits (utilisateur ${ODOO_USER}, 750)..."
chown -R "${ODOO_USER}:${ODOO_USER}" "$OPERATIONS_DIR"
find "$OPERATIONS_DIR" -type d -exec chmod 750 {} \;

# Verification : ${COUNT} modules, chacun avec ses 3 sous-dossiers.
EXPECTED=$((COUNT * 3))
ACTUAL=$(find "$OPERATIONS_DIR" -mindepth 2 -maxdepth 2 -type d | wc -l)
if [ "$ACTUAL" -ne "$EXPECTED" ]; then
  echo "[SOPD] ERREUR : ${ACTUAL} sous-dossiers trouves, ${EXPECTED} attendus (${COUNT} modules x 3)." >&2
  exit 1
fi

echo "[SOPD] OK (${COUNT} modules, ${ACTUAL} sous-dossiers rcv/snd/arc)."
exit 0
