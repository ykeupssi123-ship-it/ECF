#!/bin/bash
# ECFRCRCL - ECF_CRM_RUN_CREATELEAD - Premier job metier reel (Tier 1)
# du CRM, generique et reutilisable par n'importe quel client, jamais
# lie a une societe fictive (voir docs/CONVENTION_NOMMAGE.md, section
# "Groupes d'illustration"). AJOUTE LE 2026-09-04, job de reference du
# patron Tier 1 (une seule fois pour toutes les 480 combinaisons de la
# matrice MBTI - qui valide ce job, ne se traduit jamais en jobs
# distincts, voir docs/CONVENTION_NOMMAGE.md).
#
# OUT_COND=NONE (job repetable, pas de jalon permanent - voir le
# correctif de job_done()/mark_done() dans lib/commun.sh) : ce job
# tourne a CHAQUE lancement de l'orchestrateur, traite ce qui se trouve
# dans $OPERATIONS_DIR/cr/rcv a cet instant, jamais "une fois pour
# toutes" comme un job de construction.
#
# Contrat de fichier (voir docs/CONVENTION_NOMMAGE.md, "Validation
# d'en-tete avant traitement") : un CSV avec l'en-tete EXACT
# "name,partner_name,contact_name,phone,expected_revenue" - toute autre
# en-tete est rejetee AVANT de lire la moindre ligne, jamais devinee.
# Une fois traite avec succes, le fichier source est deplace vers
# arc/ (jamais laisse dans rcv/, jamais retraite au lancement suivant).
# Chaque fichier reellement traite est declare dans
# $ECF_JOB_PATHS_FILE (colonne PATH_TOUCHED de state/JOBS_HISTORY.csv).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/cr/rcv"
ARC_DIR="$OPERATIONS_DIR/cr/arc"
EXPECTED_HEADER="name,partner_name,contact_name,phone,expected_revenue"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
  echo "[ECF_CRM_RUN_CREATELEAD] Rien a traiter dans $RCV_DIR (aucun fichier .csv)."
  exit 0
fi

TOTAL_CREES=0
for f in "${FILES[@]}"; do
  echo "[ECF_CRM_RUN_CREATELEAD] Fichier trouve : $f"

  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  if [ "$ACTUAL_HEADER" != "$EXPECTED_HEADER" ]; then
    echo "[ECF_CRM_RUN_CREATELEAD] ERREUR : en-tete invalide dans $f." >&2
    echo "  attendu : $EXPECTED_HEADER" >&2
    echo "  trouve  : $ACTUAL_HEADER" >&2
    echo "  fichier laisse tel quel dans rcv/ (jamais devine, jamais traite partiellement)." >&2
    exit 1
  fi

  RESULTAT="$(_odoo_shell_exec "
import csv
Lead = env['crm.lead']
cree = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('name'):
            continue
        if Lead.search([('name', '=', row['name']), ('partner_name', '=', row.get('partner_name') or False)], limit=1):
            continue
        Lead.create({
            'name': row['name'],
            'type': 'opportunity',
            'partner_name': row.get('partner_name') or False,
            'contact_name': row.get('contact_name') or False,
            'phone': row.get('phone') or False,
            'expected_revenue': float(row['expected_revenue']) if row.get('expected_revenue') else 0.0,
        })
        cree += 1
env.cr.commit()
print('RESULTAT:', cree)
")"
  CREES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${CREES:-}" ]; then
    echo "[ECF_CRM_RUN_CREATELEAD] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_CRM_RUN_CREATELEAD] $CREES piste(s) creee(s) depuis $f."
  TOTAL_CREES=$((TOTAL_CREES + CREES))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
  echo "[ECF_CRM_RUN_CREATELEAD] Archive : $DEST"
done

echo "[ECF_CRM_RUN_CREATELEAD] OK (${#FILES[@]} fichier(s) traite(s), ${TOTAL_CREES} piste(s) creee(s) au total)."
exit 0
