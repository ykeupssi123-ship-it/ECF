#!/bin/bash
# ECFCCLOCP2 - ECF_COMPTA_CYC_CLOTUREMENSUELLE - Cloture comptable mensuelle
# (voir bin/montee_au_plan.sh, cadence MONTHLY, IN_COND=COMPTA_EOM_WINDOW_OPEN
# - ouverte le 1er de chaque mois, pour le mois qui vient de se terminer,
# meme raisonnement que TFJ_VENTES_WINDOW_OPEN ouverte a 00:05 "pour le
# jour qui vient de se terminer").
#
# DEPENDANCE METIER REELLE (catalogue des operations, colonne "Depend de") :
# cette cloture n'a de sens que si la reconciliation bancaire quotidienne
# (ECFCCPRB1) et le marqueur EOD (ECFCCLOCP1) ont bien tourne chaque jour du
# mois - mais ceci reste une DEPENDANCE METIER DOCUMENTEE, jamais une
# IN_COND technique : la fenetre TFJ_COMPTA_WINDOW_OPEN est remise a zero
# CHAQUE jour par montee_au_plan.sh (y compris le jour meme ou la fenetre
# EOM s'ouvre, dans la meme execution a 00:05) - il n'existe donc aucune
# condition technique "vivante" representant 30 executions quotidiennes
# passees a laquelle s'accrocher. Comme chez Control-M, l'assurance que le
# cycle quotidien a bien tourne tout le mois releve du SUIVI OPERATIONNEL
# (state/JOBS_HISTORY.csv, bin/view_history.sh), jamais d'un verrou de
# planification impossible a exprimer proprement.
#
# Objectif metier reel : calcule le chiffre d'affaires facture du mois
# ecoule, le montant reellement encaisse, et la balance agee des creances
# clients (impayees) - le triptyque classique d'une cloture mensuelle.
# OUT_COND=COMPTA_EOM_TERMINE (remis a zero par montee_au_plan.sh le mois
# suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cp/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/cloture_mensuelle_$(date +%Y%m).txt"

RESULTAT="$(_odoo_shell_exec "
import calendar
from datetime import date

aujourdhui = date.today()
# Mois qui vient de se terminer (aujourd'hui = 1er du mois courant)
if aujourdhui.month == 1:
    mois_prec, annee_prec = 12, aujourdhui.year - 1
else:
    mois_prec, annee_prec = aujourdhui.month - 1, aujourdhui.year
premier_jour = date(annee_prec, mois_prec, 1)
dernier_jour = date(annee_prec, mois_prec, calendar.monthrange(annee_prec, mois_prec)[1])

Move = env['account.move']
factures = Move.search([
    ('move_type', '=', 'out_invoice'),
    ('state', '=', 'posted'),
    ('invoice_date', '>=', premier_jour),
    ('invoice_date', '<=', dernier_jour),
])
ca_facture = sum(factures.mapped('amount_total'))
encaisse = sum(f.amount_total - f.amount_residual for f in factures)
impayees = factures.filtered(lambda f: f.payment_state in ('not_paid', 'partial'))
solde_du = sum(impayees.mapped('amount_residual'))

with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    fh.write(f'Cloture comptable mensuelle - {premier_jour} au {dernier_jour}\n')
    fh.write(f'Factures emises : {len(factures)}\n')
    fh.write(f'Chiffre d affaires facture : {ca_facture:.2f}\n')
    fh.write(f'Montant encaisse : {encaisse:.2f}\n')
    fh.write(f'Factures impayees en fin de mois : {len(impayees)}\n')
    fh.write(f'Solde du (balance agee) : {solde_du:.2f}\n')
print('RESULTAT:', len(factures))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_CYC_CLOTUREMENSUELLE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_COMPTA_CYC_CLOTUREMENSUELLE] Cloture mensuelle ecrite : $RAPPORT ($COUNT facture(s) du mois ecoule)."
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
