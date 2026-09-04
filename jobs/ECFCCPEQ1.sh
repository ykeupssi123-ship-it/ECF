#!/bin/bash
# ECFCCPEQ1 - ECF_COMPTA_CYC_DECLARTVA - Declaration TVA trimestrielle
# (voir bin/montee_au_plan.sh, cadence QUARTERLY, IN_COND=COMPTA_EOQ_WINDOW_OPEN
# - ouverte le 1er jour d'un nouveau trimestre, pour le trimestre qui
# vient de se terminer).
#
# DEPENDANCE METIER REELLE (catalogue, colonne "Depend de") : cette
# declaration s'appuie sur les 3 clotures mensuelles du trimestre ecoule
# (ECFCCPEM1) - meme raisonnement que ECFCCPEM1 vis-a-vis du cycle
# quotidien : dependance METIER documentee, jamais une IN_COND technique
# (le jalon COMPTA_EOM_TERMINE est remis a zero chaque mois par
# montee_au_plan.sh, y compris le mois ou le trimestre se termine).
#
# Objectif metier reel : calcule un montant simplifie de TVA nette due
# (TVA collectee sur les ventes moins TVA deductible sur les achats) pour
# le trimestre ecoule, a partir des lignes de taxe reelles (account.move.line,
# tax_ids non vide) des factures/avoirs valides. Simplifie a dessein (pas
# de gestion des taux multiples/regimes particuliers) - un point de depart
# reel pour un futur controle comptable, jamais presente comme une
# declaration fiscale definitive. OUT_COND=COMPTA_EOQ_TERMINE (remis a
# zero par montee_au_plan.sh au trimestre suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
CLOTURE_DIR="$OPERATIONS_DIR/cp/cloture"
mkdir -p "$CLOTURE_DIR"

RAPPORT="$CLOTURE_DIR/declaration_tva_$(date +%Y%m).txt"

RESULTAT="$(_odoo_shell_exec "
from datetime import date

aujourdhui = date.today()
# Trimestre qui vient de se terminer (aujourd'hui = 1er jour d'un nouveau
# trimestre : janvier, avril, juillet ou octobre)
trimestre_courant = (aujourdhui.month - 1) // 3 + 1
if trimestre_courant == 1:
    t_prec, annee_prec = 4, aujourdhui.year - 1
else:
    t_prec, annee_prec = trimestre_courant - 1, aujourdhui.year
premier_mois = (t_prec - 1) * 3 + 1
premier_jour = date(annee_prec, premier_mois, 1)
if premier_mois + 2 == 12:
    dernier_jour = date(annee_prec, 12, 31)
else:
    import calendar
    dernier_mois = premier_mois + 2
    dernier_jour = date(annee_prec, dernier_mois, calendar.monthrange(annee_prec, dernier_mois)[1])

Move = env['account.move']
ventes = Move.search([
    ('move_type', 'in', ['out_invoice', 'out_refund']),
    ('state', '=', 'posted'),
    ('invoice_date', '>=', premier_jour),
    ('invoice_date', '<=', dernier_jour),
])
achats = Move.search([
    ('move_type', 'in', ['in_invoice', 'in_refund']),
    ('state', '=', 'posted'),
    ('invoice_date', '>=', premier_jour),
    ('invoice_date', '<=', dernier_jour),
])
# amount_tax est toujours positif (montant de taxe brut du document,
# quel que soit son type) - le signe metier (un avoir REDUIT la taxe
# collectee/deductible) est applique explicitement ici, jamais suppose
# a partir d'un champ '_signed' dont la convention de signe varie selon
# les versions d'Odoo.
tva_collectee = sum(m.amount_tax if m.move_type == 'out_invoice' else -m.amount_tax for m in ventes)
tva_deductible = sum(m.amount_tax if m.move_type == 'in_invoice' else -m.amount_tax for m in achats)
tva_nette = tva_collectee - tva_deductible

with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    fh.write(f'Declaration TVA (simplifiee) - T{t_prec} {annee_prec} ({premier_jour} au {dernier_jour})\n')
    fh.write(f'Factures/avoirs de vente : {len(ventes)}\n')
    fh.write(f'Factures/avoirs d achat : {len(achats)}\n')
    fh.write(f'TVA collectee (ventes) : {tva_collectee:.2f}\n')
    fh.write(f'TVA deductible (achats) : {tva_deductible:.2f}\n')
    fh.write(f'TVA nette due (estimee) : {tva_nette:.2f}\n')
    fh.write('AVERTISSEMENT : calcul simplifie a des fins de pilotage interne, ne remplace pas une declaration fiscale officielle.\n')
print('RESULTAT:', len(ventes) + len(achats))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_CYC_DECLARTVA] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_COMPTA_CYC_DECLARTVA] Declaration TVA trimestrielle ecrite : $RAPPORT ($COUNT ecriture(s) analysee(s))."
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
