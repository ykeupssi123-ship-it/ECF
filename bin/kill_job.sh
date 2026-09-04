#!/bin/bash
# bin/kill_job.sh - "Kill/Terminate" : envoie un signal d'arret reel a un job
# EN COURS D'EXECUTION, ajoute le 2026-09-01. Equivalent fonctionnel du
# Kill Control-M - SIGTERM d'abord (arret propre), escalade en SIGKILL si
# le processus survit encore apres quelques secondes.
#
# Usage :
#   ./bin/kill_job.sh <JOB_ID> "<raison>"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
RAISON="${2:-}"
if [ -z "$JOB_ID" ] || [ -z "$RAISON" ]; then
  echo "Usage : ./bin/kill_job.sh <JOB_ID> \"<raison>\""
  echo "La raison est obligatoire (audit - on ne tue jamais un job sans dire pourquoi)."
  exit 1
fi
RAISON_SAFE="${RAISON//,/;}"

RUNNING_MARK="$STATE_DIR/RUNNING/${JOB_ID}.running"
if [ ! -f "$RUNNING_MARK" ]; then
  echo "$JOB_ID n'est pas actuellement en cours d'execution (aucun marqueur RUNNING). Rien a tuer."
  exit 0
fi

PID="$(cut -d',' -f2 "$RUNNING_MARK")"
if ! pid_alive "$PID"; then
  echo "$JOB_ID a un marqueur RUNNING mais le PID ($PID) ne repond plus - deja termine, nettoyage du marqueur."
  rm -f "$RUNNING_MARK"
  exit 0
fi

echo "=================================================="
echo " KILL / TERMINATE - $JOB_ID (PID $PID)"
echo "=================================================="
echo "Raison : $RAISON_SAFE"
echo ""
read -r -p "Tapez exactement '$JOB_ID' pour confirmer l'arret force : " CONFIRM
if [ "$CONFIRM" != "$JOB_ID" ]; then
  echo "Confirmation incorrecte. Rien n'a ete arrete."
  exit 1
fi

OPERATEUR="$(whoami)@$(hostname 2>/dev/null || echo host-inconnu)"
HISTORY_LEDGER="$STATE_DIR/JOBS_HISTORY.csv"
[ -f "$HISTORY_LEDGER" ] || echo "TIMESTAMP,JOB_ID,JOB_NAME,RESULT,LOG_FILE" > "$HISTORY_LEDGER"

echo "Envoi de SIGTERM (arret propre) au PID $PID..."
kill -TERM "$PID" 2>/dev/null || true
for i in 1 2 3 4 5; do
  pid_alive "$PID" || break
  sleep 1
done

if pid_alive "$PID"; then
  echo "Toujours actif apres 5s - escalade en SIGKILL..."
  kill -KILL "$PID" 2>/dev/null || true
  sleep 1
fi

rm -f "$RUNNING_MARK"
if pid_alive "$PID"; then
  echo "$JOB_ID -> ECHEC DU KILL, le processus $PID resiste encore. Investiguer manuellement." >&2
  echo "$(date -Iseconds),$JOB_ID,$JOB_ID,KILL_ECHEC,-," >> "$HISTORY_LEDGER"
  exit 1
fi

echo "$JOB_ID (PID $PID) TUE par $OPERATEUR le $(date -Iseconds)."
echo "$(date -Iseconds),$JOB_ID,$JOB_ID,TUE,-," >> "$HISTORY_LEDGER"
echo "Marque TUE dans l'historique (jamais confondu avec un ECHEC naturel du script) : ./bin/view_history.sh $JOB_ID"
