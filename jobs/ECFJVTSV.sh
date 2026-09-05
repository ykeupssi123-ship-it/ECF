#!/bin/bash
# ECFJVTSV - ECF_VENTE_JOUR_SUIVI - Job JOUR reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete JOUR/TFJ/EOD/EOM).
#
# DIFFERENT d'un job Tier 1 classique ou d'un cycle TFJ : un job JOUR
# tourne PENDANT la journee, a frequence fixe/horaires ouvres (ici
# implemente comme une garde horaire interne - le job est invoque a
# chaque passage de l'orchestrateur, comme n'importe quel OUT_COND=NONE,
# mais ne fait un vrai travail QUE dans la plage horaire configuree ;
# combine au minuteur periodique de l'orchestrateur, 15 min, voir
# setup/installer_service_orchestrateur_periodique.sh, ca donne un
# controle intraday reel sans minuteur systemd dedie par job).
#
# Objectif metier reel : suivi intraday des devis ENVOYES au client
# (state=sent, en attente de retour) depuis plus de 2h sans reponse -
# alerte precoce, pendant les heures ouvrees, distincte du nettoyage de
# fond TFJ (qui traite les devis BROUILLON, jamais envoyes). Rapport
# ecrit dans $OPERATIONS_DIR/vt/snd. OUT_COND=NONE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

HEURE_DEBUT=8
HEURE_FIN=18
HEURE_COURANTE="$(date +%H | sed 's/^0//')"

if [ "$HEURE_COURANTE" -lt "$HEURE_DEBUT" ] || [ "$HEURE_COURANTE" -ge "$HEURE_FIN" ]; then
  echo "[ECF_VENTE_JOUR_SUIVI] Hors plage horaire ouvree (${HEURE_DEBUT}h-${HEURE_FIN}h, il est ${HEURE_COURANTE}h) - rien a faire."
  exit 0
fi

SND_DIR="$OPERATIONS_DIR/vt/snd"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/suivi_jour_devis_$(date +%Y%m%d_%H%M).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Order = env['sale.order']
seuil = datetime.now() - timedelta(hours=2)
devis = Order.search([('state', '=', 'sent'), ('write_date', '<', seuil)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['quote_ref', 'partner', 'heures_sans_reponse'])
    for d in devis:
        h = (datetime.now() - d.write_date).total_seconds() / 3600
        writer.writerow([d.client_order_ref or d.name, d.partner_id.name, round(h, 1)])
print('RESULTAT:', len(devis))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_VENTE_JOUR_SUIVI] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

if [ "$COUNT" -eq 0 ]; then
  rm -f "$RAPPORT"
  echo "[ECF_VENTE_JOUR_SUIVI] Aucun devis envoye sans reponse depuis plus de 2h."
  exit 0
fi

echo "[ECF_VENTE_JOUR_SUIVI] $COUNT devis envoye(s) sans reponse depuis plus de 2h - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
