#!/bin/bash
# ECFCPRG1 - ECF_SYS_CYC_PURGE - Cycle PURGE reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete). IN_COND=PURGE_ARC_WINDOW_OPEN
# (ouverte une fois par mois par montee_au_plan.sh, cadence MONTHLY -
# voir CYCLE_WINDOWS).
#
# Role reel : archivage a froid des fichiers deja traites
# ($ECFOP/<module>/arc/) de plus de PURGE_RETENTION_JOURS (90 par
# defaut) - jamais une suppression definitive silencieuse, un
# DEPLACEMENT vers une zone d'archive froide distincte
# (operations_archive_froide/), hors du perimetre operationnel courant
# mais toujours consultable pour audit. OUT_COND=PURGE_ARC_TERMINE -
# job qui marque la fin du cycle, remis a zero le mois suivant par
# montee_au_plan.sh.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

PURGE_RETENTION_JOURS="${PURGE_RETENTION_JOURS:-90}"
mkdir -p "$ARCHIVE_FROIDE_DIR"

TOTAL_DEPLACES=0
while IFS= read -r ARC_DIR; do
  [ -z "$ARC_DIR" ] && continue
  MODULE="$(basename "$(dirname "$ARC_DIR")")"
  DEST_DIR="$ARCHIVE_FROIDE_DIR/$MODULE"
  mkdir -p "$DEST_DIR"
  while IFS= read -r -d '' FICHIER; do
    mv "$FICHIER" "$DEST_DIR/"
    echo "$DEST_DIR/$(basename "$FICHIER")" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
    TOTAL_DEPLACES=$((TOTAL_DEPLACES + 1))
  done < <(find "$ARC_DIR" -maxdepth 1 -type f -mtime "+${PURGE_RETENTION_JOURS}" -print0 2>/dev/null)
done < <(find "$OPERATIONS_DIR" -maxdepth 2 -type d -name "$DOSSIER_ARCHIVE" 2>/dev/null)

echo "[ECF_SYS_CYC_PURGE] $TOTAL_DEPLACES fichier(s) de plus de ${PURGE_RETENTION_JOURS} jours deplace(s) vers $ARCHIVE_FROIDE_DIR."
exit 0
