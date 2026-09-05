#!/bin/bash
# ECFJSTRU - ECF_STOCK_JOUR_RUPTURE - Job NRT reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete). IN_COND=STOCK_ACTIVE
# (meme convention que ECFJVTSV/VENTE_ACTIVE - un job JOUR/NRT n'a pas de
# fenetre calendaire, seule la garantie que le module existe compte).
#
# DIFFERENT d'un job JOUR classique (comme ECFJVTSV, garde horaire
# ouvree 8h-18h) : NRT est CONTINU par nature (voir taxonomie - "fil de
# l'eau", une rupture de stock peut survenir a toute heure) - donc
# AUCUNE garde horaire ici, contrairement a ECFJVTSV. La frequence reelle
# vient uniquement du minuteur periodique de l'orchestrateur (15 min).
#
# Objectif metier reel : liste les produits dont le stock disponible
# reel (qty_available) est descendu a zero ou en dessous - alerte
# precoce de rupture, jamais decouverte a la vente suivante. Rapport
# ecrit dans $OPERATIONS_DIR/st/snd (sous-dossier canonique), seulement
# s'il y a au moins une rupture (meme discipline que ECFJVTSV - pas de
# fichier vide qui polluerait le dossier a chaque passage de
# l'orchestrateur). OUT_COND=NONE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
SND_DIR="$OPERATIONS_DIR/st/snd"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/alerte_rupture_$(date +%Y%m%d_%H%M).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
Product = env['product.product']
en_rupture = Product.search([('type', '=', 'product'), ('qty_available', '<=', 0)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['produit', 'stock_disponible'])
    for p in en_rupture:
        writer.writerow([p.display_name, p.qty_available])
print('RESULTAT:', len(en_rupture))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_STOCK_JOUR_RUPTURE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

if [ "$COUNT" -eq 0 ]; then
  rm -f "$RAPPORT"
  echo "[ECF_STOCK_JOUR_RUPTURE] Aucun produit en rupture."
  exit 0
fi

echo "[ECF_STOCK_JOUR_RUPTURE] $COUNT produit(s) en rupture - alerte : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
