#!/bin/bash
# montee_au_plan.sh - Equivalent fonctionnel du "New Day"/Active Plan
# Control-M, ajoute le 2026-09-04 (demande explicite utilisateur -
# capture d'ecran reelle Control-M, "montee au plan" = un snapshot d'un
# cycle de traitement journalier).
#
# ROLE REEL (pas cosmetique) : un traitement cyclique (EOD/EOM) a besoin
# d'un jalon PERSISTANT et REEL (OUT_COND classique, pas NONE) pour
# garantir qu'il ne tourne qu'UNE FOIS par cycle - mais un jalon
# persistant, une fois marque, resterait marque POUR TOUJOURS,
# empechant le meme traitement de tourner le cycle suivant. Ce script
# est ce qui REMET LE COMPTEUR A ZERO au bon moment (calendrier) :
# jamais l'orchestrateur lui-meme (il ne sait rien du calendrier), un
# processus separe, dedie, explicite.
#
# Pour chaque cycle enregistre dans CYCLE_WINDOWS ci-dessous :
#   - Si le cycle n'a pas encore ete "ouvert" pour la periode en cours
#     (jour pour DAILY, mois pour MONTHLY) : archive le jalon terminal
#     de la periode precedente (etat REEL, jamais suppose), efface les
#     jalons de la chaine (window + terminal) pour repartir propre, puis
#     OUVRE la fenetre (marque la condition WINDOW_OPEN) - la chaine de
#     jobs redevient eligible au prochain passage de orchestrator.sh.
#   - Sinon : ne fait rien (idempotent - relancer ce script plusieurs
#     fois le meme jour/mois pour un meme cycle est sans effet apres la
#     premiere fois).
# Ecrit un instantane dat, state/plan/<AAAA-MM-JJ>.csv - LE plan du
# jour, consultable, jamais recalcule retroactivement.
#
# Installe comme minuteur systemd quotidien (voir
# setup/installer_service_montee_au_plan.sh), 00:05 par defaut -
# TOUJOURS avant que quoi que ce soit d'autre ne tourne ce jour-la.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

PLAN_DIR="$STATE_DIR/plan"
PLAN_HISTORY_DIR="$PLAN_DIR/history"
mkdir -p "$PLAN_DIR" "$PLAN_HISTORY_DIR"

TODAY="$(date +%Y-%m-%d)"
TODAY_DOM="$(date +%d)"        # jour du mois (pour MONTHLY)
MONTH_KEY="$(date +%Y-%m)"

# Registre des cycles connus - AJOUTER UNE LIGNE ICI pour chaque
# nouveau cycle (jamais devine, jamais implicite) :
#   [CONDITION_WINDOW_OPEN]="CADENCE:CONDITION_TERMINALE:LIBELLE"
# CADENCE : DAILY (tous les jours) ou MONTHLY (le 1er du mois).
declare -A CYCLE_WINDOWS=(
  [EOD_VENTES_WINDOW_OPEN]="DAILY:EOD_VENTES_TERMINE:Ventes - cloture quotidienne (relance devis, nettoyage, rapport)"
)

PLAN_FILE="$PLAN_DIR/${TODAY}.csv"
[ -f "$PLAN_FILE" ] || echo "DATE,CONDITION_WINDOW,CADENCE,STATUT,LIBELLE" > "$PLAN_FILE"

for WINDOW_COND in "${!CYCLE_WINDOWS[@]}"; do
  IFS=':' read -r CADENCE TERMINAL_COND LIBELLE <<< "${CYCLE_WINDOWS[$WINDOW_COND]}"

  case "$CADENCE" in
    DAILY)
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${TODAY}"
      ;;
    MONTHLY)
      if [ "$TODAY_DOM" != "01" ]; then
        echo "$TODAY,$WINDOW_COND,$CADENCE,PAS_DU_JOUR,$LIBELLE" >> "$PLAN_FILE"
        continue
      fi
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${MONTH_KEY}"
      ;;
    *)
      echo "[montee_au_plan] ERREUR : cadence inconnue '$CADENCE' pour $WINDOW_COND (verifier CYCLE_WINDOWS)." >&2
      continue
      ;;
  esac

  if [ -f "$DUE_MARK" ]; then
    echo "[montee_au_plan] $WINDOW_COND deja ouvert pour cette periode - rien a faire."
    echo "$TODAY,$WINDOW_COND,$CADENCE,DEJA_OUVERT,$LIBELLE" >> "$PLAN_FILE"
    continue
  fi

  # Archive le jalon terminal du cycle precedent (etat REEL) avant de
  # l'effacer - jamais une perte silencieuse d'information.
  if [ -f "$STATE_DIR/${TERMINAL_COND}.ok" ]; then
    cp "$STATE_DIR/${TERMINAL_COND}.ok" "$PLAN_HISTORY_DIR/${TERMINAL_COND}_$(date +%Y%m%d_%H%M%S).ok"
    rm -f "$STATE_DIR/${TERMINAL_COND}.ok"
  fi
  rm -f "$STATE_DIR/${WINDOW_COND}.ok"

  mark_done "$WINDOW_COND"
  touch "$DUE_MARK"
  echo "[montee_au_plan] $WINDOW_COND OUVERT ($LIBELLE) - la chaine redevient eligible au prochain ./orchestrator.sh."
  echo "$TODAY,$WINDOW_COND,$CADENCE,OUVERT,$LIBELLE" >> "$PLAN_FILE"
done

echo "[montee_au_plan] Plan du jour ecrit : $PLAN_FILE"
exit 0
