#!/bin/bash
# ECFRAHPO - ECF_ACHAT_RUN_CREATEPO - Job metier Tier 1 (voir
# ECFRCRCL/CRM et ECFRVTDV/Ventes pour le patron de reference complet,
# docs/CONVENTION_NOMMAGE.md). Cree une commande fournisseur
# (purchase.order, brouillon) avec une ou plusieurs lignes de
# produits. OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact
# "po_ref,partner_name,product_name,quantity" - PLUSIEURS lignes
# partageant le meme po_ref forment UNE SEULE commande a plusieurs
# lignes. po_ref est ecrit dans le champ standard Odoo partner_ref
# (reference fournisseur) - c'est ce champ, jamais le numero de
# sequence auto-genere par Odoo (P00001...), que ECFRAHCF/CONFIRMPO et
# ECFRAHRC/RECEIVE utilisent ensuite pour retrouver cette commande.
# Auto-routage par en-tete.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/ah/rcv"
ARC_DIR="$OPERATIONS_DIR/ah/arc"
EXPECTED_HEADER="po_ref,partner_name,product_name,quantity"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_CMD=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_ACHAT_RUN_CREATEPO] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
from collections import OrderedDict
PO = env['purchase.order']
Partner = env['res.partner']
Product = env['product.product']

groupes = OrderedDict()
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('po_ref'):
            continue
        groupes.setdefault(row['po_ref'], []).append(row)

cmd_creees = 0
for po_ref, lignes in groupes.items():
    if PO.search([('partner_ref', '=', po_ref)], limit=1):
        continue
    partner = Partner.search([('name', '=', lignes[0]['partner_name'])], limit=1)
    if not partner:
        print('IGNORE:', po_ref, '- fournisseur introuvable:', lignes[0]['partner_name'])
        continue
    order_lines = []
    for l in lignes:
        product = Product.search([('name', '=', l['product_name'])], limit=1)
        if not product:
            print('IGNORE ligne:', po_ref, '- produit introuvable:', l['product_name'])
            continue
        order_lines.append((0, 0, {
            'product_id': product.id,
            'product_qty': float(l['quantity']),
            'product_uom': product.uom_po_id.id,
            'price_unit': product.standard_price,
            'date_planned': __import__('datetime').datetime.now(),
        }))
    if not order_lines:
        continue
    PO.create({
        'partner_id': partner.id,
        'partner_ref': po_ref,
        'order_line': order_lines,
    })
    cmd_creees += 1
env.cr.commit()
print('RESULTAT:', cmd_creees)
")"
  CMD="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${CMD:-}" ]; then
    echo "[ECF_ACHAT_RUN_CREATEPO] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_ACHAT_RUN_CREATEPO] $CMD commande(s) fournisseur creee(s) depuis $f."
  TOTAL_CMD=$((TOTAL_CMD + CMD))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_ACHAT_RUN_CREATEPO] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_ACHAT_RUN_CREATEPO] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_CMD} commande(s) creee(s) au total)."
exit 0
