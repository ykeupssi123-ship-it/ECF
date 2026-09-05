#!/bin/bash
# ECFJRELEC1 - ECF_ECOM_JOUR_RELANCEPANIER - Job JOUR/NRT reel (voir
# bin/montee_au_plan.sh, meme patron que ECFJALRVT1/ECFJALRRP1).
# IN_COND=ECOM_ACTIVE, OUT_COND=NONE (continu). PAS de garde horaire
# interne (une boutique en ligne recoit des visiteurs 24h/24,
# contrairement au suivi devis B2B en heures ouvrees).
#
# Objectif metier reel : relance les clients ayant rempli un panier en
# ligne (sale.order, state='draft', website_id renseigne) sans
# finaliser leur achat depuis plus de 4h - seuil plus large que la
# simple detection (ECFCCLOEC1, 2h) pour laisser une vraie chance de
# finaliser avant de relancer. Notification simulee (rapport
# exploitable dans snd/, meme perimetre que ECFJALRRP1 - jamais un
# envoi email reel non configure). Ne relance jamais deux fois le
# meme panier (marqueur par commande, state/paniers_relances/).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/ec/$DOSSIER_PRODUIT"
RELANCE_DIR="$STATE_DIR/paniers_relances"
mkdir -p "$SND_DIR" "$RELANCE_DIR"
RAPPORT="$SND_DIR/relance_paniers_$(date +%Y%m%d_%H%M).csv"
SEUIL_HEURES="${ECOM_RELANCE_SEUIL_HEURES:-4}"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Order = env['sale.order']
seuil = datetime.now() - timedelta(hours=${SEUIL_HEURES})
paniers = Order.search([('website_id', '!=', False), ('state', '=', 'draft'), ('write_date', '<', seuil)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['panier', 'client', 'montant', 'heures_inactif'])
    for p in paniers:
        h = (datetime.now() - p.write_date).total_seconds() / 3600
        print('CLE:' + p.name)
        writer.writerow([p.name, p.partner_id.name if p.partner_id else '', p.amount_total, round(h, 1)])
print('RESULTAT:', len(paniers))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_ECOM_JOUR_RELANCEPANIER] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

NOUVEAU=0
while IFS= read -r cle; do
  [ -z "$cle" ] && continue
  MARQUEUR="$RELANCE_DIR/$(echo "$cle" | tr '/: ' '___')"
  if [ ! -f "$MARQUEUR" ]; then
    touch "$MARQUEUR"
    NOUVEAU=$((NOUVEAU + 1))
  fi
done < <(echo "$RESULTAT" | grep -o 'CLE:.*' | sed 's/^CLE://')

if [ "$NOUVEAU" -eq 0 ]; then
  rm -f "$RAPPORT"
  echo "[ECF_ECOM_JOUR_RELANCEPANIER] Aucun panier a relancer (deja relances ou aucun panier inactif depuis ${SEUIL_HEURES}h)."
  exit 0
fi

echo "[ECF_ECOM_JOUR_RELANCEPANIER] $NOUVEAU nouveau(x) panier(s) a relancer sur $COUNT detecte(s) - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
