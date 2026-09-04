#!/bin/bash
# ECFRVTCF - ECF_VENTE_RUN_CONFIRMORDER - Job metier Tier 1 (voir
# ECFRCRCL/CRM pour le patron de reference complet,
# docs/CONVENTION_NOMMAGE.md). Confirme un devis existant (brouillon)
# en commande de vente reelle (action_confirm). OUT_COND=NONE
# (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "order_to_confirm" - la
# valeur client_order_ref (pas le numero de sequence Odoo) d'un devis
# cree par ECFRVTDV/CREATEDEVIS. Auto-routage par en-tete, distinct de
# ECFRVTIN/CREATEINVOICE qui partage le meme dossier rcv/.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/vt/rcv"
ARC_DIR="$OPERATIONS_DIR/vt/arc"
EXPECTED_HEADER="order_to_confirm"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_CONFIRMEES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_VENTE_RUN_CONFIRMORDER] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Order = env['sale.order']
confirmees = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('order_to_confirm'):
            continue
        order = Order.search([('client_order_ref', '=', row['order_to_confirm']), ('state', '=', 'draft')], limit=1)
        if order:
            order.action_confirm()
            confirmees += 1
env.cr.commit()
print('RESULTAT:', confirmees)
")"
  CONFIRMEES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${CONFIRMEES:-}" ]; then
    echo "[ECF_VENTE_RUN_CONFIRMORDER] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_VENTE_RUN_CONFIRMORDER] $CONFIRMEES commande(s) confirmee(s) depuis $f."
  TOTAL_CONFIRMEES=$((TOTAL_CONFIRMEES + CONFIRMEES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_VENTE_RUN_CONFIRMORDER] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_VENTE_RUN_CONFIRMORDER] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_CONFIRMEES} commande(s) confirmee(s) au total)."
exit 0
