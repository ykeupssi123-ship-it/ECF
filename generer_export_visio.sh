#!/bin/bash
# generer_export_visio.sh - Genere un CSV compatible Microsoft Visio
# Data Visualizer (extension NATIVE de Visio/Excel qui transforme un
# tableau structure en organigramme automatiquement - aucun fichier
# .vsdx binaire fabrique a la main, format proprietaire trop complexe
# pour etre genere fiablement hors de Visio lui-meme).
#
# AJOUTE LE 2026-09-04 (demande explicite utilisateur, voir
# docs/JOURNAL_TECHNIQUE.md). Vue AU NIVEAU SERVICE (colonne SERVICE de
# jobs_table.csv), pas job par job : verifie en reel que ODOO_SYSTEME_PRET
# a lui seul debloque 39 jobs individuels - un diagramme job-par-job
# produirait un noeud a 39 branches, illisible. Le niveau service (38
# noeuds : SYS + 34 modules + 3 groupes d'illustration) donne la vraie
# vue globale demandee, fidele a l'architecture reelle (chaque module
# ne depend QUE du systeme, jamais d'un autre module).
#
# Colonnes produites (convention Data Visualizer, gabarit "Cross-
# Functional Flowchart" - la colonne Group pilote les couloirs/swimlanes
# a l'import) : ID, Shape, Text, Group, 1, 2, 3... (colonnes numerotees
# = connexions sortantes, autant que necessaire). A l'import dans
# Visio/Excel (onglet Donnees > Visualisateur de donnees, ou
# Insertion > Diagrammes ajoute-in), verifier que les noms de colonnes
# de l'assistant correspondent a ceux-ci - si votre version de Visio
# utilise un intitule legerement different, renommez juste l'entete,
# les donnees restent valables.
#
# Usage : ./generer_export_visio.sh [fichier_sortie.csv]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS_CSV="$SCRIPT_DIR/jobs_table.csv"
OUT_FILE="${1:-$SCRIPT_DIR/docs/CARTOGRAPHIE_VISIO_SERVICES.csv}"

[ -f "$JOBS_CSV" ] || { echo "ERREUR : $JOBS_CSV introuvable." >&2; exit 1; }

# Etiquette lisible + groupe (couloir) par service - construite a la
# main (pas devinee) a partir de docs/CONVENTION_NOMMAGE.md et
# jobs_table.csv, pour que le libelle affiche dans Visio ait un sens
# immediat (pas juste le code brut "CR").
declare -A LABEL=(
  [SYS]="SYS - Installation systeme (PostgreSQL - Odoo - Nginx...)"
  [CT]="Contacts" [CL]="Calendrier" [DS]="Discuss" [CR]="CRM" [VT]="Vente"
  [CP]="Comptabilite" [AH]="Achat" [ST]="Stock" [MR]="MRP (fabrication)"
  [RP]="Reparation (SAV)" [FL]="Flotte vehicules" [PS]="Point de vente"
  [PR]="POS Restaurant" [SI]="Site web" [EC]="eCommerce" [EV]="Evenements"
  [EL]="eLearning" [JW]="Offres d'emploi web" [RH]="RH (fiches employes)"
  [PN]="Presences" [CG]="Conges" [ND]="Notes de frais" [RC]="Recrutement"
  [CM]="Competences" [PJ]="Projets" [TD]="Todo" [MT]="Maintenance"
  [SN]="Sondages" [CN]="Cantine" [LC]="Live chat" [EM]="Email marketing"
  [SM]="SMS marketing" [CK]="Cartes marketing" [RY]="Recyclage donnees"
  [ILL_CLIMAUTO]="Illustration - CLIM AUTO" [ILL_COUL]="Illustration - COUL"
  [ILL_BOULANGERIE]="Illustration - PAIN & GLACE"
)
declare -A GROUP=(
  [SYS]="Tier 0 - Systeme"
)
# Tout module (2 lettres, pas SYS, pas ILL_*) -> couloir "Tier 1 - Modules"
# Tout ILL_* -> couloir "Tier 2 - Illustration"

TMP_OUT="$(mktemp)"

# --- 1) Liste ordonnee des SERVICE distincts (ordre d'apparition) ---
SERVICES="$(awk -F',' 'NR>1 && $9!="" {if (!seen[$9]++) print $9}' "$JOBS_CSV")"

# --- 2) Pour chaque service, calcule ses services "downstream" reels :
#     un service B depend du service A si au moins un job de B a, dans
#     son IN_COND, un OUT_COND produit par au moins un job de A. ---
declare -A DOWNSTREAM  # DOWNSTREAM[A]="B C D" (services debloques par A)

while IFS=',' read -r JOB_ID JOB_NAME JOB_ROLE COMPONENT SCRIPT_FILE DESC IN_COND OUT_COND SERVICE; do
  [ "$JOB_ID" = "JOB_ID" ] && continue
  [ -z "${IN_COND:-}" ] || [ "$IN_COND" = "NONE" ] && continue
  IFS='|' read -ra deps <<< "$IN_COND"
  for d in "${deps[@]}"; do
    # trouve quel(s) service(s) produisent cette condition "d"
    PRODUCERS="$(awk -F',' -v c="$d" 'NR>1 && $8==c {print $9}' "$JOBS_CSV")"
    while IFS= read -r P; do
      [ -z "$P" ] && continue
      [ "$P" = "$SERVICE" ] && continue   # jamais une auto-boucle (dependance interne au meme service)
      case " ${DOWNSTREAM[$P]:-} " in
        *" ${SERVICE} "*) ;;  # deja note
        *) DOWNSTREAM[$P]="${DOWNSTREAM[$P]:-} ${SERVICE}" ;;
      esac
    done <<< "$PRODUCERS"
  done
done < "$JOBS_CSV"

# --- 3) Genere le CSV (jusqu'a 40 colonnes de connexion - couvre le
#     cas reel le plus large observe, SYS -> 34 modules). ---
MAX_CONN=40
{
  printf 'ID,Shape,Text,Group'
  for i in $(seq 1 $MAX_CONN); do printf ',%d' "$i"; done
  printf '\n'

  while IFS= read -r SVC; do
    [ -z "$SVC" ] && continue
    TEXT="${LABEL[$SVC]:-$SVC}"
    if [ "$SVC" = "SYS" ]; then
      SHAPE="Predefined process"
      GRP="Tier 0 - Systeme"
    elif [[ "$SVC" == ILL_* ]]; then
      SHAPE="Process"
      GRP="Tier 2 - Illustration"
    else
      SHAPE="Process"
      GRP="Tier 1 - Modules"
    fi
    TEXT_ESC="${TEXT//\"/\"\"}"
    printf '%s,%s,"%s","%s"' "$SVC" "$SHAPE" "$TEXT_ESC" "$GRP"
    # colonnes de connexion : chaque service downstream reel, un par colonne
    read -ra targets <<< "${DOWNSTREAM[$SVC]:-}"
    col=0
    for t in "${targets[@]}"; do
      col=$((col+1))
      [ $col -gt $MAX_CONN ] && break
      printf ',%s' "$t"
    done
    for ((r=col+1; r<=MAX_CONN; r++)); do printf ','; done
    printf '\n'
  done <<< "$SERVICES"
} > "$TMP_OUT"

mkdir -p "$(dirname "$OUT_FILE")"
mv "$TMP_OUT" "$OUT_FILE"
echo "Export ecrit dans $OUT_FILE ($(($(wc -l < "$OUT_FILE") - 1)) services)."
