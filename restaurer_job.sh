#!/bin/bash
# restaurer_job.sh - Leve la suppression (UNDELETE) d'un job, ajoute le
# 2026-09-01. Voir supprimer_job.sh.
#
# Usage :
#   ./restaurer_job.sh <JOB_ID>
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
if [ -z "$JOB_ID" ]; then
  echo "Usage : ./restaurer_job.sh <JOB_ID>"
  exit 1
fi

if ! job_deleted "$JOB_ID"; then
  echo "$JOB_ID n'est pas supprime actuellement. Rien a faire."
  exit 0
fi

echo "Marqueur de suppression actuel :"
cat "$STATE_DIR/DELETED/${JOB_ID}.deleted"
rm -f "$STATE_DIR/DELETED/${JOB_ID}.deleted"
echo ""
echo "$JOB_ID RESTAURE par $(whoami)@$(hostname 2>/dev/null || echo host-inconnu) le $(date -Iseconds)."
echo "Il reprend sa place normale dans le plan d'execution (si ses dependances sont satisfaites)."
