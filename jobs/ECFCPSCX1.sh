#!/bin/bash
# ECFCPSCX1 - ECF_PDV_CYC_CLOTURECAISSE - Cycle TFJ Point de vente (voir
# bin/montee_au_plan.sh). IN_COND=TFJ_PDV_WINDOW_OPEN. Chaine a UN SEUL
# job - terminal direct.
#
# Objectif metier reel : rapport de clôture de caisse du jour - nombre
# de commandes de caisse (pos.order) et total encaisse, par session de
# caisse (pos.session) fermee aujourd'hui. Version simplifiee reelle
# (rapport de synthese) - PAS un rapprochement physique especes/carte
# (necessiterait de lire les comptages manuels saisis par le caissier a
# la fermeture de session, deja fait par Odoo lui-meme dans son propre
# ecran de fermeture - ce job ne duplique jamais un controle deja fait
# par le logiciel, il le consolide pour l'exploitation). Rapport ecrit
# dans $OPERATIONS_DIR/ps/snd (sous-dossier canonique). OUT_COND=TFJ_PDV_TERMINE
# (REEL, remis a zero par montee_au_plan.sh le cycle suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/ps/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/cloture_caisse_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime
Session = env['pos.session']
aujourdhui = datetime.now().date()
sessions = Session.search([('state', '=', 'closed')])
sessions_jour = sessions.filtered(lambda s: s.stop_at and s.stop_at.date() == aujourdhui)
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['session', 'caissier', 'nb_commandes', 'total_encaisse'])
    for s in sessions_jour:
        writer.writerow([s.name, s.user_id.name, len(s.order_ids), f'{s.total_payments_amount:.2f}'])
print('RESULTAT:', len(sessions_jour))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_PDV_CYC_CLOTURECAISSE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_PDV_CYC_CLOTURECAISSE] $COUNT session(s) de caisse fermee(s) aujourd'hui - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_PDV_CYC_CLOTURECAISSE] Cycle TFJ Point de vente TERMINE pour aujourd'hui."
exit 0
