#!/bin/bash
# ECFCCLOEC1 - ECF_ECOM_CYC_RAPPORTVENTES - Cycle TFJ reel (voir
# bin/montee_au_plan.sh). IN_COND=ECOM_TFJ_WINDOW_OPEN (ouverte
# uniquement par montee_au_plan.sh, une fois par jour). Chaine a UN
# SEUL job - terminal direct. OUT_COND=ECOM_TFJ_TERMINE.
#
# Objectif metier reel : bilan quotidien des ventes en ligne
# (sale.order avec website_id renseigne, state confirme) et des
# paniers abandonnes en cours (state='draft', website_id renseigne,
# non modifie depuis plus de 2h - meme seuil que le suivi devis Ventes,
# ECFJALRVT1). Odoo Community n'a pas d'automatisation "panier
# abandonne" native (Marketing Automation est Enterprise) - construit
# honnetement la DETECTION reelle par requete ORM directe, jamais la
# fausse automatisation Enterprise.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/ec/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/rapport_ventes_paniers_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Order = env['sale.order']
aujourdhui = datetime.now().date()
ventes = Order.search([('website_id', '!=', False), ('state', 'in', ['sale', 'done']), ('date_order', '>=', aujourdhui)])
seuil = datetime.now() - timedelta(hours=2)
paniers = Order.search([('website_id', '!=', False), ('state', '=', 'draft'), ('write_date', '<', seuil)])
ca_jour = sum(ventes.mapped('amount_total'))
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['type', 'reference', 'client', 'montant'])
    for v in ventes:
        writer.writerow(['VENTE', v.name, v.partner_id.name if v.partner_id else '', v.amount_total])
    for p in paniers:
        writer.writerow(['PANIER_ABANDONNE', p.name, p.partner_id.name if p.partner_id else '', p.amount_total])
print('RESULTAT:', len(ventes), len(paniers), round(ca_jour, 2))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_ECOM_CYC_RAPPORTVENTES] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_ECOM_CYC_RAPPORTVENTES] Bilan du jour ecrit : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_ECOM_CYC_RAPPORTVENTES] Cycle TFJ eCommerce TERMINE pour aujourd'hui."
exit 0
