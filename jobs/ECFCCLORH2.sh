#!/bin/bash
# ECFCCLORH2 - ECF_RH_CYC_BILANSOCIAL - Cycle EOY reel (voir
# bin/montee_au_plan.sh). IN_COND=RH_EOY_WINDOW_OPEN (ouverte le 1er
# janvier uniquement, montee_au_plan.sh - PREMIER usage reel de la
# cadence YEARLY, deja implementee dans montee_au_plan.sh mais jamais
# encore utilisee par un job avant celui-ci, comme la cadence WEEKLY
# pour ECFCCLOCR1 le meme jour). Chaine a UN SEUL job - terminal
# direct. OUT_COND=RH_EOY_TERMINE.
#
# DependDe (catalogue_operations.csv) : "Rapport effectifs et
# anciennete (les 12 mois de l'annee)" - dependance METIER (le bilan
# social se lit mieux si les rapports mensuels existent deja), PAS une
# IN_COND technique (meme convention que la colonne DependDe partout
# ailleurs, voir footnote de la feuille Catalogue des operations) :
# ce job interroge directement l'annee ecoulee en base, il ne lit
# jamais les CSV mensuels produits par ECFCCLORH1.
#
# Objectif metier reel : bilan RH complet de l'annee ecoulee (entrees,
# sorties, effectif de fin d'annee) - hr.employee/hr.contract, memes
# modeles que ECFCALRRH1/ECFCCLORH1.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/rh/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
ANNEE_ECOULEE=$(( $(date +%Y) - 1 ))
RAPPORT="$SND_DIR/bilan_social_${ANNEE_ECOULEE}.txt"

RESULTAT="$(_odoo_shell_exec "
from datetime import date
Employe = env['hr.employee']
Contrat = env['hr.contract']
debut = date(${ANNEE_ECOULEE}, 1, 1)
fin = date(${ANNEE_ECOULEE}, 12, 31)
entrees = Contrat.search([('date_start', '>=', debut), ('date_start', '<=', fin)])
sorties = Employe.search([('active', '=', False), ('departure_date', '>=', debut), ('departure_date', '<=', fin)]) if 'departure_date' in Employe._fields else Employe.browse()
effectif_fin_annee = Employe.search_count([('active', '=', True)])
with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    fh.write(f'Bilan social ${ANNEE_ECOULEE}\n')
    fh.write(f'Entrees (nouveaux contrats)  : {len(entrees)}\n')
    fh.write(f'Sorties (departs enregistres) : {len(sorties)}\n')
    fh.write(f'Effectif actif (a la date d\'execution) : {effectif_fin_annee}\n')
print('RESULTAT:', len(entrees), len(sorties), effectif_fin_annee)
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_RH_CYC_BILANSOCIAL] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_RH_CYC_BILANSOCIAL] Bilan social ${ANNEE_ECOULEE} ecrit : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_RH_CYC_BILANSOCIAL] Cycle EOY RH TERMINE pour cette annee."
exit 0
