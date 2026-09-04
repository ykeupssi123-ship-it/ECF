#!/bin/bash
# generer_export_controlm.sh - Genere une representation XML de
# jobs_table.csv, au format proche d'un export reel Control-M
# (DEFTABLE > FOLDER par SERVICE > JOB > INCOND/OUTCOND).
#
# AJOUTE LE 2026-09-04 (demande explicite utilisateur, voir
# docs/JOURNAL_TECHNIQUE.md) : le moteur d'EXECUTION reste bash+CSV
# (jobs_table.csv, orchestrator.sh) - fiable, deja eprouve, jamais
# remplace. Ce script produit UNIQUEMENT une vue XML DOCUMENTAIRE de la
# meme donnee, pour deux raisons distinctes :
#   1) Fidelite pedagogique : reproduire le formalisme reel d'echange
#      Control-M (FOLDER/JOB/INCOND/OUTCOND), utile pour l'apprentissage
#      et la demonstration de maitrise de l'outil.
#   2) Documentation toujours a jour : regenere a la demande depuis
#      jobs_table.csv (source de verite unique), jamais une copie
#      maintenue a la main qui pourrait diverger.
# Regroupement par FOLDER = colonne SERVICE (voir orchestrator.sh et
# docs/CONVENTION_NOMMAGE.md pour le detail de l'isolation de panne par
# service que cette colonne pilote reellement a l'execution).
#
# Usage : ./generer_export_controlm.sh [fichier_sortie.xml]
# Par defaut : docs/CONTROLM_EXPORT.xml
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JOBS_CSV="$PROJECT_ROOT/jobs_table.csv"
OUT_FILE="${1:-$PROJECT_ROOT/docs/CONTROLM_EXPORT.xml}"

[ -f "$JOBS_CSV" ] || { echo "ERREUR : $JOBS_CSV introuvable." >&2; exit 1; }

xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  printf '%s' "$s"
}

TMP_OUT="$(mktemp)"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo "<!-- Genere automatiquement par generer_export_controlm.sh depuis jobs_table.csv - NE PAS EDITER A LA MAIN, rejouer le script apres toute modification de jobs_table.csv. -->"
  echo '<DEFTABLE>'

  # Liste ordonnee des SERVICE distincts (colonne 9), dans leur premier
  # ordre d'apparition dans le fichier - jamais triee alphabetiquement,
  # pour rester lisible dans le meme ordre que jobs_table.csv.
  SERVICES="$(awk -F',' 'NR>1 && $9!="" {if (!seen[$9]++) print $9}' "$JOBS_CSV")"

  while IFS= read -r SVC; do
    [ -z "$SVC" ] && continue
    SVC_ESC="$(xml_escape "$SVC")"
    echo "  <FOLDER FOLDER_NAME=\"${SVC_ESC}\">"
    awk -F',' -v svc="$SVC" 'NR>1 && $9==svc {print}' "$JOBS_CSV" | while IFS=',' read -r JOB_ID JOB_NAME JOB_ROLE COMPONENT SCRIPT_FILE DESC IN_COND OUT_COND SERVICE; do
      JOB_ID_ESC="$(xml_escape "$JOB_ID")"
      JOB_NAME_ESC="$(xml_escape "$JOB_NAME")"
      DESC_ESC="$(xml_escape "$DESC")"
      SCRIPT_ESC="$(xml_escape "$SCRIPT_FILE")"
      echo "    <JOB JOBNAME=\"${JOB_ID_ESC}\" APPLICATION=\"ERP_CRM_FACTORY\" SUB_APPLICATION=\"${SVC_ESC}\" MEMNAME=\"${JOB_NAME_ESC}\" CMDLINE=\"jobs/${SCRIPT_ESC}\" DESCRIPTION=\"${DESC_ESC}\">"
      if [ -n "$IN_COND" ] && [ "$IN_COND" != "NONE" ]; then
        IFS='|' read -ra deps <<< "$IN_COND"
        for d in "${deps[@]}"; do
          d_esc="$(xml_escape "$d")"
          echo "      <INCOND NAME=\"${d_esc}\" ODATE=\"ODAT\" AND_OR=\"A\"/>"
        done
      fi
      if [ -n "$OUT_COND" ]; then
        out_esc="$(xml_escape "$OUT_COND")"
        echo "      <OUTCOND NAME=\"${out_esc}\" ODATE=\"ODAT\" SIGN=\"ADD\"/>"
      fi
      echo "    </JOB>"
    done
    echo "  </FOLDER>"
  done <<< "$SERVICES"

  echo '</DEFTABLE>'
} > "$TMP_OUT"

mkdir -p "$(dirname "$OUT_FILE")"
mv "$TMP_OUT" "$OUT_FILE"
echo "Export ecrit dans $OUT_FILE ($(grep -c '<JOB ' "$OUT_FILE") jobs, $(grep -c '<FOLDER ' "$OUT_FILE") services/FOLDER)."
