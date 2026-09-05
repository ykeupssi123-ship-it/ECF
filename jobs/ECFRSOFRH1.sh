#!/bin/bash
# ECFRSOFRH1 - ECF_RH_RUN_OFFBOARDING - Job Tier 1 reel (voir
# ECFRCRCL.sh pour le patron RUN generique : fichier depose dans rcv/,
# traite, archive dans arc/, jamais retraite). IN_COND=RH_ACTIVE,
# OUT_COND=NONE (repetable, comme tous les jobs RUN de ce projet).
#
# DependDe (catalogue_operations.csv) : "Alerte fin de contrat (si
# depart lie a une echeance de contrat)" - dependance METIER
# (ECFCALRRH1 peut avoir signale l'echeance en amont), PAS une IN_COND
# technique : un depart peut aussi etre une demission ou une rupture,
# jamais uniquement une fin de contrat planifiee - ce job traite les
# deux cas sans distinction technique.
#
# Contrat de fichier : un CSV avec l'en-tete EXACT
# "employee_name,departure_date,departure_reason" - toute autre
# en-tete est rejetee AVANT de lire la moindre ligne (meme discipline
# que ECFRCRCL.sh).
#
# Objectif metier reel : liste de controle du depart (retrait des
# acces = archivage de la fiche employe, active=False ; recuperation
# du materiel et archivage du dossier = checklist ecrite, jamais
# automatisee au-dela de ce qu'Odoo Community permet reellement -
# 'departure_reason_id'/'departure_date' sont des champs standard
# hr.employee en Community, utilises ici tels quels).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

RCV_DIR="$OPERATIONS_DIR/rh/$DOSSIER_RECU"
SND_DIR="$OPERATIONS_DIR/rh/$DOSSIER_PRODUIT"
ARC_DIR="$OPERATIONS_DIR/rh/$DOSSIER_ARCHIVE"
EXPECTED_HEADER="employee_name,departure_date,departure_reason"

mkdir -p "$RCV_DIR" "$SND_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

if [ ${#FILES[@]} -eq 0 ]; then
  echo "[ECF_RH_RUN_OFFBOARDING] Rien a traiter dans $RCV_DIR (aucun fichier .csv)."
  exit 0
fi

TOTAL_TRAITES=0
for f in "${FILES[@]}"; do
  echo "[ECF_RH_RUN_OFFBOARDING] Fichier trouve : $f"

  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  if [ "$ACTUAL_HEADER" != "$EXPECTED_HEADER" ]; then
    echo "[ECF_RH_RUN_OFFBOARDING] ERREUR : en-tete invalide dans $f." >&2
    echo "  attendu : $EXPECTED_HEADER" >&2
    echo "  trouve  : $ACTUAL_HEADER" >&2
    echo "  fichier laisse tel quel dans rcv/ (jamais devine, jamais traite partiellement)." >&2
    exit 1
  fi

  CHECKLIST="$SND_DIR/checklist_depart_$(date +%Y%m%d_%H%M%S).csv"
  RESULTAT="$(_odoo_shell_exec "
import csv
Employe = env['hr.employee']
traites = 0
lignes_checklist = []
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        nom = row.get('employee_name')
        if not nom:
            continue
        emp = Employe.search([('name', '=', nom), ('active', '=', True)], limit=1)
        if not emp:
            lignes_checklist.append([nom, 'INTROUVABLE', 'NON', 'NON', 'NON'])
            continue
        vals = {'active': False}
        if 'departure_date' in emp._fields and row.get('departure_date'):
            vals['departure_date'] = row['departure_date']
        emp.write(vals)
        lignes_checklist.append([nom, 'OK', 'OUI (fiche archivee)', 'A_FAIRE_MANUELLEMENT', 'OUI (fiche conservee)'])
        traites += 1
env.cr.commit()
with open('${CHECKLIST}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['employe', 'statut', 'retrait_acces', 'recuperation_materiel', 'archivage_dossier'])
    for l in lignes_checklist:
        writer.writerow(l)
print('RESULTAT:', traites)
")"
  TRAITES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${TRAITES:-}" ]; then
    echo "[ECF_RH_RUN_OFFBOARDING] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_RH_RUN_OFFBOARDING] $TRAITES depart(s) traite(s) depuis $f - checklist : $CHECKLIST"
  echo "$CHECKLIST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
  TOTAL_TRAITES=$((TOTAL_TRAITES + TRAITES))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
  echo "[ECF_RH_RUN_OFFBOARDING] Archive : $DEST"
done

echo "[ECF_RH_RUN_OFFBOARDING] OK (${#FILES[@]} fichier(s) traite(s), ${TOTAL_TRAITES} depart(s) au total)."
exit 0
