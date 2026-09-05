#!/bin/bash
# ECFJALRRP1 - ECF_REPAIR_JOUR_AVANCEMENT - Job JOUR reel (voir
# bin/montee_au_plan.sh, meme patron que ECFJALRVT1). IN_COND=
# REPAIR_ACTIVE, OUT_COND=NONE (continu, garde horaire interne
# 8h-18h - un client n'est jamais notifie a 3h du matin).
#
# Objectif metier reel : previent le client des que sa reparation
# change d'etape suivie ("prise en charge" = confirmed/under_repair,
# "terminee" = done), via le modele reel repair.order (application
# Repair, disponible en Community). Notification simulee ici sous
# forme de rapport ecrit dans snd/ (pas d'envoi SMS/email reel cote
# atelier - meme perimetre que les autres jobs de ce projet : produire
# la liste exploitable, jamais un vrai envoi vers un canal non
# configure). Ne re-notifie jamais deux fois le meme changement d'etat
# (marque via un fichier d'etat par ordre, state/repair_notifie/).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

HEURE_DEBUT=8
HEURE_FIN=18
HEURE_COURANTE="$(date +%H | sed 's/^0//')"

if [ "$HEURE_COURANTE" -lt "$HEURE_DEBUT" ] || [ "$HEURE_COURANTE" -ge "$HEURE_FIN" ]; then
  echo "[ECF_REPAIR_JOUR_AVANCEMENT] Hors plage horaire ouvree (${HEURE_DEBUT}h-${HEURE_FIN}h, il est ${HEURE_COURANTE}h) - rien a faire."
  exit 0
fi

SND_DIR="$OPERATIONS_DIR/rp/$DOSSIER_PRODUIT"
NOTIFIE_DIR="$STATE_DIR/repair_notifie"
mkdir -p "$SND_DIR" "$NOTIFIE_DIR"
RAPPORT="$SND_DIR/notification_avancement_$(date +%Y%m%d_%H%M).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
Repair = env['repair.order']
ordres = Repair.search([('state', 'in', ['under_repair', 'done'])])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['ordre', 'client', 'nouvel_etat'])
    for o in ordres:
        cle = f'{o.name}:{o.state}'
        print('CLE:' + cle)
        writer.writerow([o.name, o.partner_id.name if o.partner_id else '', o.state])
print('RESULTAT:', len(ordres))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_REPAIR_JOUR_AVANCEMENT] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

NOUVEAU=0
while IFS= read -r cle; do
  [ -z "$cle" ] && continue
  MARQUEUR="$NOTIFIE_DIR/$(echo "$cle" | tr '/: ' '___')"
  if [ ! -f "$MARQUEUR" ]; then
    touch "$MARQUEUR"
    NOUVEAU=$((NOUVEAU + 1))
  fi
done < <(echo "$RESULTAT" | grep -o 'CLE:.*' | sed 's/^CLE://')

if [ "$NOUVEAU" -eq 0 ]; then
  rm -f "$RAPPORT"
  echo "[ECF_REPAIR_JOUR_AVANCEMENT] Aucun changement d'etape non deja notifie."
  exit 0
fi

echo "[ECF_REPAIR_JOUR_AVANCEMENT] $NOUVEAU nouvelle(s) notification(s) sur $COUNT ordre(s) suivis - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
