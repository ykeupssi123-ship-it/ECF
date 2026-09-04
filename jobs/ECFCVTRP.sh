#!/bin/bash
# ECFCVTRP - ECF_VENTE_CYC_RAPPORT - 3e et DERNIER job du cycle TFJ
# Ventes (voir ECFCVTRL pour le patron complet). IN_COND=TFJ_VENTES_NETTOYAGE_OK.
#
# Objectif metier reel : rapport de fin de journee (commandes
# confirmees aujourd'hui, chiffre d'affaires du jour) - ecrit dans
# $ECFOP/vt/snd, jamais juste affiche puis perdu. OUT_COND=TFJ_VENTES_TERMINE
# - JOB QUI MARQUE LA FIN DU TRAITEMENT (voir la capture Control-M
# fournie en session : le dernier job d'une chaine, celui qu'on regarde
# pour savoir "le cycle du jour est-il termine ?"). Remis a zero par
# bin/montee_au_plan.sh le lendemain, jamais par ce job lui-meme.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
SND_DIR="$OPERATIONS_DIR/vt/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/rapport_eod_$(date +%Y%m%d).txt"

RESULTAT="$(_odoo_shell_exec "
from datetime import datetime
Order = env['sale.order']
aujourdhui = datetime.now().date()
commandes = Order.search([('state', '=', 'sale')])
commandes_jour = commandes.filtered(lambda o: o.date_order and o.date_order.date() == aujourdhui)
ca_jour = sum(commandes_jour.mapped('amount_total'))
with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    fh.write(f'Rapport EOD Ventes - {aujourdhui}\n')
    fh.write(f'Commandes confirmees aujourd hui : {len(commandes_jour)}\n')
    fh.write(f'Chiffre d affaires du jour : {ca_jour:.2f}\n')
print('RESULTAT:', len(commandes_jour))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_VENTE_CYC_RAPPORT] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_VENTE_CYC_RAPPORT] Rapport EOD ecrit : $RAPPORT ($COUNT commande(s) confirmee(s) aujourd'hui)."
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_VENTE_CYC_RAPPORT] Cycle EOD Ventes TERMINE pour aujourd'hui."
exit 0
