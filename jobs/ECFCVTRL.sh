#!/bin/bash
# ECFCVTRL - ECF_VENTE_CYC_RELANCE - Premier job du cycle TFJ Ventes
# (voir bin/montee_au_plan.sh, docs/CONVENTION_NOMMAGE.md section
# "Cycles calendaires"). IN_COND=TFJ_VENTES_WINDOW_OPEN (ouverte
# uniquement par montee_au_plan.sh, une fois par jour).
#
# Objectif metier reel : detecter les devis (sale.order, state=draft)
# vieux de plus de 5 jours - jamais relance automatique par email ici
# (aucune garantie que le serveur SMTP reel soit configure sur toute
# instance) - le rapport est ecrit dans $ECFOP/vt/snd pour qu'un
# commercial (ou un futur job d'envoi) le traite. OUT_COND=TFJ_VENTES_RELANCE_OK
# (REEL, pas NONE - remis a zero par montee_au_plan.sh le cycle
# suivant, jamais par ce job lui-meme).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
SND_DIR="$OPERATIONS_DIR/vt/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/relance_devis_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Order = env['sale.order']
seuil = datetime.now() - timedelta(days=5)
devis = Order.search([('state', '=', 'draft'), ('create_date', '<', seuil)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['quote_ref', 'partner', 'age_jours', 'montant'])
    for d in devis:
        age = (datetime.now() - d.create_date).days
        writer.writerow([d.client_order_ref or d.name, d.partner_id.name, age, d.amount_total])
print('RESULTAT:', len(devis))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_VENTE_CYC_RELANCE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_VENTE_CYC_RELANCE] $COUNT devis en attente depuis plus de 5 jours - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
