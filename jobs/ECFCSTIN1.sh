#!/bin/bash
# ECFCSTIN1 - ECF_STOCK_CYC_INVENTAIRE - Cycle TFJ Stock (voir
# bin/montee_au_plan.sh). IN_COND=TFJ_STOCK_WINDOW_OPEN. Chaine a UN SEUL
# job - terminal direct.
#
# Objectif metier reel : valorisation nocturne du stock reel (jamais un
# comptage physique automatise - impossible sans materiel de terrain,
# uniquement ce que le systeme sait deja) - quantite disponible x cout
# standard (product.product.standard_price) par produit, plus le total
# general. Rapport ecrit dans $OPERATIONS_DIR/st/snd (sous-dossier
# canonique). OUT_COND=TFJ_STOCK_TERMINE (REEL, remis a zero par
# montee_au_plan.sh le cycle suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/st/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/valorisation_stock_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
Product = env['product.product']
produits = Product.search([('type', '=', 'product'), ('qty_available', '>', 0)])
valeur_totale = 0.0
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['produit', 'quantite', 'cout_unitaire', 'valeur'])
    for p in produits:
        valeur = p.qty_available * p.standard_price
        valeur_totale += valeur
        writer.writerow([p.display_name, p.qty_available, p.standard_price, f'{valeur:.2f}'])
    writer.writerow(['TOTAL', '', '', f'{valeur_totale:.2f}'])
print('RESULTAT:', len(produits))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_STOCK_CYC_INVENTAIRE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_STOCK_CYC_INVENTAIRE] Valorisation de $COUNT produit(s) ecrite : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_STOCK_CYC_INVENTAIRE] Cycle TFJ Stock TERMINE pour aujourd'hui."
exit 0
