#!/bin/bash
# ECFJSCORCR1 - ECF_CRM_JOUR_SCORING - Job NRT reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete). IN_COND=CRM_ACTIVE,
# OUT_COND=NONE (continu - invoque a chaque passage du minuteur
# periodique de l'orchestrateur, 15 min, comme ECFJALRVT1/ECFJALRST1).
#
# CONSOLIDATION HONNETE (catalogue_operations.csv estimait 2 jobs
# "calcul - mise a jour") : le motif OUT_COND=NONE qui permet la
# repetition continue (voir lib/commun.sh, job_done("NONE") toujours
# faux) ne permet PAS de chainer proprement 2 jobs eux-memes continus
# via IN_COND/OUT_COND (un OUT_COND reel resterait "fait" pour
# toujours, cassant la repetition du 2e job) - calcul et ecriture sont
# donc faits ICI en un seul job, comme deja fait pour d'autres
# operations "Lineaire" a 2-3 etapes cette meme session (ex.
# ECFCCLOVT2). Voir docs/JOURNAL_TECHNIQUE.md.
#
# Objectif metier reel : Odoo Community n'a PAS de scoring predictif
# (Lead Scoring est Enterprise) - construit honnetement le sous-ensemble
# reel possible : un score simple 0-3 base sur des signaux reels deja
# presents sur la fiche (telephone renseigne, montant attendu au-dessus
# d'un seuil, anciennete de la piste), ecrit dans le champ standard
# 'priority' (etoiles, deja utilise par le kanban CRM natif) - jamais
# un faux "score IA". Ne traite que les pistes actives non closes.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cr/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/score_qualification_$(date +%Y%m%d_%H%M).csv"
SEUIL_MONTANT="${CRM_SCORE_SEUIL_MONTANT:-5000}"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date
Lead = env['crm.lead']
pistes = Lead.search([('type', '=', 'lead'), ('active', '=', True)])
maj = 0
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['piste', 'telephone_renseigne', 'montant_attendu', 'anciennete_jours', 'score_0_a_3'])
    for p in pistes:
        score = 0
        if p.phone:
            score += 1
        if (p.expected_revenue or 0) >= ${SEUIL_MONTANT}:
            score += 1
        anciennete = (date.today() - p.create_date.date()).days if p.create_date else 0
        if anciennete <= 3:
            score += 1
        niveau = {0: '0', 1: '1', 2: '2', 3: '3'}[score]
        if p.priority != niveau:
            p.write({'priority': niveau})
            maj += 1
        writer.writerow([p.name, bool(p.phone), p.expected_revenue or 0, anciennete, score])
env.cr.commit()
print('RESULTAT:', len(pistes), maj)
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
MAJ="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $3}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_CRM_JOUR_SCORING] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_CRM_JOUR_SCORING] $COUNT piste(s) evaluee(s), $MAJ score(s) mis a jour - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
