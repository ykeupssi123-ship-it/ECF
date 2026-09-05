#!/bin/bash
# ECFCCLOCR1 - ECF_CRM_CYC_PIPELINEHEBDO - Cycle EOW reel (voir
# bin/montee_au_plan.sh). IN_COND=CRM_EOW_WINDOW_OPEN (ouverte le
# samedi uniquement, montee_au_plan.sh - PREMIER usage reel de la
# cadence WEEKLY, deja implementee dans montee_au_plan.sh mais jamais
# encore utilisee par un job avant celui-ci). Chaine a UN SEUL job -
# terminal direct. OUT_COND=CRM_EOW_TERMINE.
#
# CONSOLIDATION HONNETE (catalogue estimait 3 jobs "extraction - KPI -
# envoi") : l'envoi email n'est pas construit ici (necessiterait un
# gabarit de message et un choix de destinataire distincts de
# bin/notifier.sh, qui n'alerte que sur ECHEC de job - hors perimetre
# de ce chantier) - le rapport est ecrit dans snd/, consultable comme
# tous les autres rapports. Extraction et calcul KPI faits en un seul
# job (meme raisonnement que les autres operations "Lineaire"
# consolidees cette session).
#
# Objectif metier reel : bilan hebdomadaire du pipeline commercial -
# nouvelles pistes creees, opportunites gagnees/perdues, valeur totale
# du pipeline ouvert (crm.lead, deja utilise par ECFRCRCL/CO/MV/WO/LO).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cr/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/pipeline_hebdomadaire_$(date +%Y%m%d).txt"

RESULTAT="$(_odoo_shell_exec "
from datetime import date, timedelta
Lead = env['crm.lead']
il_y_a_7j = date.today() - timedelta(days=7)
nouvelles = Lead.search([('type', '=', 'lead'), ('create_date', '>=', il_y_a_7j)])
gagnees = Lead.search([('type', '=', 'opportunity'), ('probability', '=', 100), ('date_closed', '>=', il_y_a_7j)])
perdues = Lead.search([('type', '=', 'opportunity'), ('active', '=', False), ('probability', '=', 0), ('date_closed', '>=', il_y_a_7j)])
ouvertes = Lead.search([('type', '=', 'opportunity'), ('active', '=', True), ('probability', '<', 100)])
valeur_pipeline = sum(ouvertes.mapped('expected_revenue'))
valeur_gagnee = sum(gagnees.mapped('expected_revenue'))
with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    fh.write(f'Bilan pipeline commercial - semaine se terminant le {date.today()}\n')
    fh.write(f'Nouvelles pistes (7 derniers jours) : {len(nouvelles)}\n')
    fh.write(f'Opportunites gagnees                : {len(gagnees)} (valeur : {valeur_gagnee:.2f})\n')
    fh.write(f'Opportunites perdues                 : {len(perdues)}\n')
    fh.write(f'Pipeline ouvert (en cours)            : {len(ouvertes)} opportunite(s), valeur totale {valeur_pipeline:.2f}\n')
print('RESULTAT:', len(nouvelles), len(gagnees), len(perdues), len(ouvertes))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_CRM_CYC_PIPELINEHEBDO] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_CRM_CYC_PIPELINEHEBDO] Bilan hebdomadaire ecrit : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_CRM_CYC_PIPELINEHEBDO] Cycle EOW CRM TERMINE pour cette semaine."
exit 0
