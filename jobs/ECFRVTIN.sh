#!/bin/bash
# ECFRVTIN - ECF_VENTE_RUN_CREATEINVOICE - Job metier Tier 1 (voir
# ECFRCRCL/CRM pour le patron de reference complet,
# docs/CONVENTION_NOMMAGE.md). Cree et valide la facture d'une
# commande de vente confirmee (_create_invoices + action_post).
# OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "order_to_invoice" - la
# valeur client_order_ref (pas le numero de sequence Odoo) d'une
# commande confirmee par ECFRVTCF/CONFIRMORDER. Auto-routage par
# en-tete, distinct de ECFRVTCF/CONFIRMORDER qui partage le meme
# dossier rcv/.
#
# Note d'independance des modules (voir docs/CONVENTION_NOMMAGE.md,
# "Regle non negociable") : facturer une commande necessite, cote
# Odoo, que le module account (Comptabilite/CP) soit installe -
# volontairement PAS ajoute en IN_COND (ce serait une dependance VT->CP
# entre deux modules business, rejetee par
# bin/verifier_independance_modules.sh). A la place, verifie et echoue
# clairement au moment de l'execution (jamais une exception Odoo brute
# et cryptique) si account n'est pas installe - le module Vente reste
# installable independamment, seule CETTE action precise du pipeline
# echoue si son prealable metier reel n'est pas rempli.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

RCV_DIR="$OPERATIONS_DIR/vt/rcv"
ARC_DIR="$OPERATIONS_DIR/vt/arc"
EXPECTED_HEADER="order_to_invoice"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_FACTUREES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_VENTE_RUN_CREATEINVOICE] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Module = env['ir.module.module']
account_mod = Module.search([('name', '=', 'account'), ('state', '=', 'installed')], limit=1)
assert account_mod, 'module account (Comptabilite) non installe - facturation impossible'
Order = env['sale.order']
facturees = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('order_to_invoice'):
            continue
        order = Order.search([('client_order_ref', '=', row['order_to_invoice']), ('state', '=', 'sale')], limit=1)
        if not order or order.invoice_status == 'invoiced':
            continue
        invoices = order._create_invoices()
        invoices.action_post()
        facturees += 1
env.cr.commit()
print('RESULTAT:', facturees)
")"
  FACTUREES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${FACTUREES:-}" ]; then
    echo "[ECF_VENTE_RUN_CREATEINVOICE] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f (voir sortie ci-dessus - module account manquant ?)." >&2
    exit 1
  fi
  echo "[ECF_VENTE_RUN_CREATEINVOICE] $FACTUREES commande(s) facturee(s) depuis $f."
  TOTAL_FACTUREES=$((TOTAL_FACTUREES + FACTUREES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_VENTE_RUN_CREATEINVOICE] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_VENTE_RUN_CREATEINVOICE] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_FACTUREES} commande(s) facturee(s) au total)."
exit 0
