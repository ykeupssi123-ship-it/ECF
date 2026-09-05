#!/bin/bash
# ECFCCPRB1 - ECF_COMPTA_CYC_RECONBANK - 1er job du cycle TFJ Comptabilite
# (voir bin/montee_au_plan.sh, meme patron que le cycle TFJ Ventes
# ECFCRELVT1/NT/RP). IN_COND=TFJ_COMPTA_WINDOW_OPEN (ouverte uniquement par
# montee_au_plan.sh, une fois par jour).
#
# Objectif metier reel : detecte les lignes de releve bancaire
# (account.bank.statement.line) non encore rapprochees (is_reconciled=False)
# de plus de 2 jours - un ecart de reconciliation qui traine est le
# premier signal d'un probleme (paiement non lettre, doublon, erreur de
# saisie). Rapport ecrit dans $OPERATIONS_DIR/cp/snd (sous-dossier
# canonique "fichiers produits", voir jobs/ECFBOPD.sh), jamais juste
# affiche.
# OUT_COND=TFJ_COMPTA_RECONBANK_OK (REEL, remis a zero par
# montee_au_plan.sh le cycle suivant, jamais par ce job lui-meme).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cp/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/reconciliation_bancaire_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Line = env['account.bank.statement.line']
seuil = datetime.now() - timedelta(days=2)
lignes = Line.search([('is_reconciled', '=', False), ('date', '<', seuil.date())])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['statement_line_ref', 'date', 'montant', 'age_jours'])
    for l in lignes:
        age = (datetime.now().date() - l.date).days
        writer.writerow([l.payment_ref or l.name, l.date, l.amount, age])
print('RESULTAT:', len(lignes))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_CYC_RECONBANK] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_COMPTA_CYC_RECONBANK] $COUNT ligne(s) de releve non rapprochee(s) depuis plus de 2 jours - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
