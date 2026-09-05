#!/bin/bash
# ECFRVTDV - ECF_VENTE_RUN_CREATEDEVIS - Job metier Tier 1 (voir
# ECFRCRCL/CRM pour le patron de reference complet,
# docs/CONVENTION_NOMMAGE.md). Cree un devis (sale.order, brouillon)
# avec une ou plusieurs lignes de produits. OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact
# "quote_ref,partner_name,product_name,quantity" - PLUSIEURS lignes
# partageant le meme quote_ref forment UN SEUL devis a plusieurs
# lignes. quote_ref est ecrit dans le champ standard Odoo
# client_order_ref (reference client) - c'est ce champ, jamais le
# numero de sequence auto-genere par Odoo (S00001...), que
# ECFRVTCF/CONFIRMORDER et ECFRVTIN/CREATEINVOICE utilisent ensuite
# pour retrouver ce devis. Auto-routage par en-tete.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

RCV_DIR="$OPERATIONS_DIR/vt/$DOSSIER_RECU"
ARC_DIR="$OPERATIONS_DIR/vt/$DOSSIER_ARCHIVE"
EXPECTED_HEADER="quote_ref,partner_name,product_name,quantity"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_DEVIS=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_VENTE_RUN_CREATEDEVIS] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
from collections import OrderedDict
Order = env['sale.order']
Partner = env['res.partner']
Product = env['product.product']

groupes = OrderedDict()
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('quote_ref'):
            continue
        groupes.setdefault(row['quote_ref'], []).append(row)

devis_crees = 0
for quote_ref, lignes in groupes.items():
    if Order.search([('client_order_ref', '=', quote_ref)], limit=1):
        continue
    partner = Partner.search([('name', '=', lignes[0]['partner_name'])], limit=1)
    if not partner:
        print('IGNORE:', quote_ref, '- client introuvable:', lignes[0]['partner_name'])
        continue
    order_lines = []
    for l in lignes:
        product = Product.search([('name', '=', l['product_name'])], limit=1)
        if not product:
            print('IGNORE ligne:', quote_ref, '- produit introuvable:', l['product_name'])
            continue
        order_lines.append((0, 0, {
            'product_id': product.id,
            'product_uom_qty': float(l['quantity']),
        }))
    if not order_lines:
        continue
    Order.create({
        'partner_id': partner.id,
        'client_order_ref': quote_ref,
        'order_line': order_lines,
    })
    devis_crees += 1
env.cr.commit()
print('RESULTAT:', devis_crees)
")"
  DEVIS="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${DEVIS:-}" ]; then
    echo "[ECF_VENTE_RUN_CREATEDEVIS] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_VENTE_RUN_CREATEDEVIS] $DEVIS devis cree(s) depuis $f."
  TOTAL_DEVIS=$((TOTAL_DEVIS + DEVIS))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_VENTE_RUN_CREATEDEVIS] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_VENTE_RUN_CREATEDEVIS] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_DEVIS} devis cree(s) au total)."
exit 0
