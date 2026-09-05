#!/bin/bash
# ECFCAHRA1 - ECF_ACHAT_CYC_REAPPRO - Cycle TFJ Achat (voir
# bin/montee_au_plan.sh, meme patron que le cycle TFJ Ventes).
# IN_COND=TFJ_ACHAT_WINDOW_OPEN. Chaine a UN SEUL job - terminal direct.
#
# Objectif metier reel : s'appuie sur les regles de reapprovisionnement
# reelles d'Odoo (stock.warehouse.orderpoint - fonctionnalite native,
# jamais un seuil invente) pour lister les produits dont le stock
# disponible est descendu sous le minimum defini. PROPOSE une liste
# (rapport), ne cree AUCUNE commande fournisseur automatiquement - une
# creation reelle de bon de commande reste une decision humaine, meme
# principe que ECFCRELVT1 qui ne relance jamais un client par email tout
# seul. OUT_COND=TFJ_ACHAT_TERMINE (REEL, remis a zero par
# montee_au_plan.sh le cycle suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/ah/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/reappro_propose_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
Orderpoint = env['stock.warehouse.orderpoint']
regles = Orderpoint.search([])
a_reapprovisionner = regles.filtered(lambda r: r.product_id.qty_available < r.product_min_qty)
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['produit', 'stock_actuel', 'seuil_min', 'quantite_max_cible'])
    for r in a_reapprovisionner:
        writer.writerow([r.product_id.display_name, r.product_id.qty_available, r.product_min_qty, r.product_max_qty])
print('RESULTAT:', len(a_reapprovisionner))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_ACHAT_CYC_REAPPRO] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_ACHAT_CYC_REAPPRO] $COUNT produit(s) sous le seuil minimum - propositions : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_ACHAT_CYC_REAPPRO] Cycle TFJ Achat TERMINE pour aujourd'hui."
exit 0
