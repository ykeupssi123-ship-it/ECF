#!/bin/bash
# ECFRAHRC - ECF_ACHAT_RUN_RECEIVE - Job metier Tier 1 (voir
# ECFRCRCL/CRM et ECFRVTDV/Ventes pour le patron de reference complet,
# docs/CONVENTION_NOMMAGE.md). Receptionne les marchandises d'une
# commande fournisseur confirmee (valide le(s) bon(s) de reception
# stock.picking generes automatiquement par Odoo). OUT_COND=NONE
# (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "po_to_receive" - la
# valeur partner_ref (pas le numero de sequence Odoo) d'une commande
# confirmee par ECFRAHCF/CONFIRMPO. Auto-routage par en-tete, distinct
# de ECFRAHCF/CONFIRMPO qui partage le meme dossier rcv/.
#
# Note d'independance des modules (meme principe que ECFRVTIN/Ventes,
# voir docs/CONVENTION_NOMMAGE.md, "Regle non negociable") : la
# generation d'un bon de reception (stock.picking) necessite, cote
# Odoo, que le module stock soit installe - volontairement PAS ajoute
# en IN_COND (ce serait AH->ST entre deux modules business, rejete par
# bin/verifier_independance_modules.sh). Verifie et echoue clairement
# a l'execution si stock n'est pas installe.
#
# ATTENTION - PAS ENCORE VERIFIE SUR UNE VRAIE INSTANCE ODOO 19 (contrairement
# aux autres jobs Tier 1 de ce module, qui reutilisent des patrons deja
# executes en reel via les jobs d'illustration) : button_validate() sur
# un stock.picking suppose que les quantites reservees/a traiter
# correspondent deja aux quantites commandees (cas normal d'une
# premiere reception complete). A tester sur une VM reelle avant
# exploitation en production - voir docs/JOURNAL_TECHNIQUE.md.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/ah/rcv"
ARC_DIR="$OPERATIONS_DIR/ah/arc"
EXPECTED_HEADER="po_to_receive"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_RECUES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_ACHAT_RUN_RECEIVE] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Module = env['ir.module.module']
stock_mod = Module.search([('name', '=', 'stock'), ('state', '=', 'installed')], limit=1)
assert stock_mod, 'module stock non installe - reception impossible'
PO = env['purchase.order']
recues = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('po_to_receive'):
            continue
        po = PO.search([('partner_ref', '=', row['po_to_receive']), ('state', '=', 'purchase')], limit=1)
        if not po:
            continue
        pickings = po.picking_ids.filtered(lambda p: p.state not in ('done', 'cancel'))
        for pick in pickings:
            pick.button_validate()
        if pickings:
            recues += 1
env.cr.commit()
print('RESULTAT:', recues)
")"
  RECUES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${RECUES:-}" ]; then
    echo "[ECF_ACHAT_RUN_RECEIVE] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f (voir sortie ci-dessus - module stock manquant ou reception partielle ?)." >&2
    exit 1
  fi
  echo "[ECF_ACHAT_RUN_RECEIVE] $RECUES commande(s) receptionnee(s) depuis $f."
  TOTAL_RECUES=$((TOTAL_RECUES + RECUES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_ACHAT_RUN_RECEIVE] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_ACHAT_RUN_RECEIVE] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_RECUES} commande(s) receptionnee(s) au total)."
exit 0
