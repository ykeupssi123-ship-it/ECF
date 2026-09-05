#!/bin/bash
# ECFJINTCP1 - ECF_COMPTA_JOUR_EXPORTINTRADAY - Job INTRADAY reel (voir
# taxonomie complete, feuille "Taxonomie complete" du tableau de bord).
# IN_COND=COMPTA_ACTIVE, OUT_COND=NONE (continu, comme les jobs JOUR/NRT
# deja construits) - MAIS un job INTRADAY est different d'un job
# JOUR/NRT continu : il ne travaille qu'A DES HEURES FIXES precises
# dans la journee (10h/14h/16h, comme un cut-off interbancaire),
# jamais en continu ni une seule fois par jour. Meme minuteur
# periodique 15 min que tous les jobs de ce projet
# (setup/installer_service_orchestrateur_periodique.sh) - la garde
# horaire est faite ICI, en comparant l'heure courante a chaque
# creneau cible, avec un marqueur PAR CRENEAU PAR JOUR pour n'exporter
# qu'UNE SEULE FOIS par creneau meme si l'orchestrateur repasse
# plusieurs fois dans le meme quart d'heure.
#
# Objectif metier reel : exporte les ecritures comptables
# (account.move, state='posted') du jour vers un systeme externe a des
# heures fixes - typiquement pour alimenter un outil de reporting
# tiers sans attendre la cloture EOD. PREMIER job INTRADAY construit
# (comble le seul type de la taxonomie complete sans exemple reel
# avant celui-ci, avec ECFCDIFCP1 pour DIFFERE - voir
# docs/JOURNAL_TECHNIQUE.md).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

HEURES_CIBLES=(10 14 16)
HEURE_COURANTE="$(date +%H | sed 's/^0//')"
AUJOURDHUI="$(date +%Y%m%d)"

CIBLE_ATTEINTE=""
for h in "${HEURES_CIBLES[@]}"; do
  if [ "$HEURE_COURANTE" -eq "$h" ]; then
    CIBLE_ATTEINTE="$h"
    break
  fi
done

if [ -z "$CIBLE_ATTEINTE" ]; then
  echo "[ECF_COMPTA_JOUR_EXPORTINTRADAY] Hors creneau (cibles : ${HEURES_CIBLES[*]}h, il est ${HEURE_COURANTE}h) - rien a faire."
  exit 0
fi

MARQUEUR_DIR="$STATE_DIR/intraday_cp"
mkdir -p "$MARQUEUR_DIR"
MARQUEUR="$MARQUEUR_DIR/${AUJOURDHUI}_${CIBLE_ATTEINTE}h.ok"
if [ -f "$MARQUEUR" ]; then
  echo "[ECF_COMPTA_JOUR_EXPORTINTRADAY] Creneau ${CIBLE_ATTEINTE}h deja exporte aujourd'hui - rien a refaire."
  exit 0
fi

SND_DIR="$OPERATIONS_DIR/cp/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/export_intraday_${AUJOURDHUI}_${CIBLE_ATTEINTE}h.csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date
Move = env['account.move']
ecritures = Move.search([('state', '=', 'posted'), ('date', '=', date.today())])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['piece_comptable', 'journal', 'montant_total', 'partenaire'])
    for m in ecritures:
        writer.writerow([m.name, m.journal_id.name if m.journal_id else '', m.amount_total, m.partner_id.name if m.partner_id else ''])
print('RESULTAT:', len(ecritures))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_JOUR_EXPORTINTRADAY] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

touch "$MARQUEUR"
echo "[ECF_COMPTA_JOUR_EXPORTINTRADAY] Export ${CIBLE_ATTEINTE}h : $COUNT ecriture(s) postee(s) aujourd'hui - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
