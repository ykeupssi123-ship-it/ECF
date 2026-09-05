#!/bin/bash
# ECFCVTEM1 - ECF_VENTE_CYC_CLOTUREMENSUELLE - Cloture commerciale
# mensuelle (voir bin/montee_au_plan.sh, cadence MONTHLY,
# IN_COND=VENTES_EOM_WINDOW_OPEN - ouverte le 1er de chaque mois, pour le
# mois qui vient de se terminer).
#
# DEPENDANCE METIER REELLE (catalogue, colonne "Depend de") : cette
# cloture s'appuie sur le cycle TFJ Ventes quotidien (ECFCVTRL/NT/RP)
# ayant tourne chaque jour du mois - meme raisonnement documente que
# ECFCCPEM1 cote Comptabilite : dependance METIER, jamais une IN_COND
# technique (voir ECFCCPEM1.sh pour l'explication complete du choix).
#
# Objectif metier reel : chiffre d'affaires confirme du mois ecoule et
# repartition par commercial (base de calcul des commissions) - le calcul
# le plus direct pour un rapport d'objectifs commerciaux mensuel.
# OUT_COND=VENTES_EOM_TERMINE (remis a zero par montee_au_plan.sh le mois
# suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
SND_DIR="$OPERATIONS_DIR/vt/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/cloture_commerciale_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import calendar
import csv
from collections import defaultdict
from datetime import date

aujourdhui = date.today()
if aujourdhui.month == 1:
    mois_prec, annee_prec = 12, aujourdhui.year - 1
else:
    mois_prec, annee_prec = aujourdhui.month - 1, aujourdhui.year
premier_jour = date(annee_prec, mois_prec, 1)
dernier_jour = date(annee_prec, mois_prec, calendar.monthrange(annee_prec, mois_prec)[1])

Order = env['sale.order']
commandes = Order.search([
    ('state', '=', 'sale'),
    ('date_order', '>=', premier_jour),
    ('date_order', '<=', dernier_jour),
])
par_commercial = defaultdict(lambda: [0, 0.0])
for c in commandes:
    nom = c.user_id.name or '(non assigne)'
    par_commercial[nom][0] += 1
    par_commercial[nom][1] += c.amount_total

with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['commercial', 'nb_commandes', 'ca_total'])
    for nom, (nb, ca) in sorted(par_commercial.items(), key=lambda x: -x[1][1]):
        writer.writerow([nom, nb, f'{ca:.2f}'])
print('RESULTAT:', len(commandes))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_VENTE_CYC_CLOTUREMENSUELLE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_VENTE_CYC_CLOTUREMENSUELLE] Cloture commerciale mensuelle ecrite : $RAPPORT ($COUNT commande(s) du mois ecoule)."
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
