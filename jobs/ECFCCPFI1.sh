#!/bin/bash
# ECFCCPFI1 - ECF_COMPTA_CYC_RELANCEFACT - 2e et DERNIER job du cycle TFJ
# Comptabilite (voir ECFCCPRB1 pour le patron complet). IN_COND=TFJ_COMPTA_RECONBANK_OK.
#
# Objectif metier reel : detecte les factures client (account.move,
# move_type=out_invoice, state=posted) dont l'echeance (invoice_date_due)
# est depassee et qui ne sont pas encore payees (payment_state in
# not_paid/partial) - jamais de relance email automatique ici (meme choix
# que ECFCVTRL : aucune garantie qu'un serveur SMTP reel soit configure
# sur toute instance), le rapport est ecrit pour qu'un comptable (ou un
# futur job d'envoi) le traite. OUT_COND=TFJ_COMPTA_TERMINE - JOB QUI
# MARQUE LA FIN DU CYCLE (remis a zero par montee_au_plan.sh le
# lendemain, jamais par ce job lui-meme).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cp/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/relance_factures_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime
Move = env['account.move']
aujourdhui = datetime.now().date()
factures = Move.search([
    ('move_type', '=', 'out_invoice'),
    ('state', '=', 'posted'),
    ('payment_state', 'in', ['not_paid', 'partial']),
    ('invoice_date_due', '<', aujourdhui),
])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['facture_ref', 'partner', 'echeance', 'retard_jours', 'montant_restant_du'])
    for f in factures:
        retard = (aujourdhui - f.invoice_date_due).days if f.invoice_date_due else 0
        writer.writerow([f.name, f.partner_id.name, f.invoice_date_due, retard, f.amount_residual])
print('RESULTAT:', len(factures))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_CYC_RELANCEFACT] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_COMPTA_CYC_RELANCEFACT] $COUNT facture(s) impayee(s) en retard - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_COMPTA_CYC_RELANCEFACT] Cycle TFJ Comptabilite TERMINE pour aujourd'hui."
exit 0
