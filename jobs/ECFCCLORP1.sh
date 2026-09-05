#!/bin/bash
# ECFCCLORP1 - ECF_REPAIR_CYC_RAPPORTSAV - Cycle TFJ reel (voir
# bin/montee_au_plan.sh). IN_COND=REPAIR_TFJ_WINDOW_OPEN (ouverte
# uniquement par montee_au_plan.sh, une fois par jour). Chaine a UN
# SEUL job - terminal direct. OUT_COND=REPAIR_TFJ_TERMINE (REEL, remis
# a zero par montee_au_plan.sh le cycle suivant).
#
# CONSOLIDATION HONNETE (catalogue estimait 2 jobs "Lineaire") : "en
# cours" et "terminees" sont 2 sections du MEME rapport quotidien, pas
# 2 traitements independants - un seul job les produit ensemble (meme
# raisonnement que les autres operations consolidees cette session).
#
# Objectif metier reel : point quotidien sur les reparations en cours
# (repair.order, state=under_repair) et terminees le jour meme
# (state=done, write_date=aujourd'hui) - visibilite atelier de fin de
# journee. Rapport ecrit dans $OPERATIONS_DIR/rp/snd.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/rp/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/rapport_sav_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date
Repair = env['repair.order']
en_cours = Repair.search([('state', '=', 'under_repair')])
terminees = Repair.search([('state', '=', 'done'), ('write_date', '>=', date.today())])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['ordre', 'client', 'statut', 'produit'])
    for o in en_cours:
        writer.writerow([o.name, o.partner_id.name if o.partner_id else '', 'EN_COURS', o.product_id.name if o.product_id else ''])
    for o in terminees:
        writer.writerow([o.name, o.partner_id.name if o.partner_id else '', 'TERMINEE_AUJOURDHUI', o.product_id.name if o.product_id else ''])
print('RESULTAT:', len(en_cours), len(terminees))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_REPAIR_CYC_RAPPORTSAV] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_REPAIR_CYC_RAPPORTSAV] Rapport SAV du jour ecrit : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_REPAIR_CYC_RAPPORTSAV] Cycle TFJ Reparation TERMINE pour aujourd'hui."
exit 0
