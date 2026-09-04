#!/bin/bash
# ECFCEOD1 - ECF_COMPTA_EOD_BASCULE - Marqueur EOD reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete JOUR/TFJ/EOD/EOM).
#
# DIFFERENT d'un cycle TFJ (chaine de plusieurs jobs, voir
# ECFCVTRL/NT/RP) : EOD est un marqueur LOGIQUE UNIQUE, horodate (ici
# 23:50 - voir setup/installer_service_eod_compta.sh, minuteur DEDIE,
# jamais celui de montee_au_plan.sh qui ouvre les cycles TFJ a 00:05).
# Role reel : basculer la date valeur comptable courante de J a J+1 -
# c'est ce jalon que les traitements TFJ de la nuit (une fois EOD passe)
# et les traitements JOUR du lendemain matin considerent comme LA
# reference. OUT_COND=NONE (comme un job Tier 1 repetable) - mais
# idempotent par construction interne (verifie la date deja marquee),
# jamais par un jalon permanent : ce marqueur DOIT etre re-ecrit chaque
# jour, contrairement a un jalon TFJ (qui doit au contraire etre remis
# a zero par montee_au_plan.sh).
#
# IN_COND=COMPTA_ACTIVE : la bascule n'a de sens que si le module
# Comptabilite est actif (meme SERVICE=CP, jamais un module different -
# verifie par bin/verifier_independance_modules.sh).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

MARQUEUR="$STATE_DIR/valeur_comptable_courante.txt"
AUDIT="$STATE_DIR/EOD_BASCULES_AUDIT.csv"
[ -f "$AUDIT" ] || echo "TIMESTAMP,ANCIENNE_DATE_VALEUR,NOUVELLE_DATE_VALEUR" > "$AUDIT"

AUJOURDHUI="$(date +%Y-%m-%d)"
ANCIENNE="$([ -f "$MARQUEUR" ] && cat "$MARQUEUR" || echo "(aucune - premiere bascule)")"

if [ "$ANCIENNE" = "$AUJOURDHUI" ]; then
  echo "[ECF_COMPTA_EOD_BASCULE] Date valeur deja basculee aujourd'hui ($AUJOURDHUI) - rien a faire."
  exit 0
fi

echo "$AUJOURDHUI" > "$MARQUEUR"
echo "$(date -Iseconds),$ANCIENNE,$AUJOURDHUI" >> "$AUDIT"
echo "[ECF_COMPTA_EOD_BASCULE] Bascule EOD : date valeur comptable $ANCIENNE -> $AUJOURDHUI."
exit 0
