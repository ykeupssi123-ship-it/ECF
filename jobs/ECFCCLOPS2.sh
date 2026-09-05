#!/bin/bash
# ECFCCLOPS2 - ECF_PDV_CYC_RAPPORTMENSUEL - Cycle EOM reel (voir
# bin/montee_au_plan.sh). IN_COND=PDV_EOM_WINDOW_OPEN (ouverte le 1er
# du mois uniquement, montee_au_plan.sh). Chaine a UN SEUL job -
# terminal direct. OUT_COND=PDV_EOM_TERMINE.
#
# Numerotation ..PS2 (jamais ..PS1, deja pris par ECFCCLOPS1 - cloture
# de caisse quotidienne, cycle TFJ distinct) : meme module (PS), meme
# pattern CLO (rapport de fin de periode), 2 cadences differentes -
# voir docs/CONVENTION_NOMMAGE.md.
#
# Objectif metier reel : une fois par mois, bilan des ventes (pos.order,
# state='paid'/'done'/'invoiced') regroupe par point de vente
# (pos.session -> config_id), pour comparer la performance entre
# points de vente.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/ps/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/rapport_ventes_mensuel_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date
Order = env['pos.order']
fin_mois = date.today().replace(day=1)
mois_prec = fin_mois.month - 1 or 12
annee_prec = fin_mois.year - 1 if fin_mois.month == 1 else fin_mois.year
debut_mois = date(annee_prec, mois_prec, 1)
commandes = Order.search([
    ('state', 'in', ['paid', 'done', 'invoiced']),
    ('date_order', '>=', debut_mois),
    ('date_order', '<', fin_mois),
])
par_pdv = {}
for c in commandes:
    pdv = c.config_id.name if c.config_id else '(inconnu)'
    par_pdv.setdefault(pdv, {'nb': 0, 'total': 0.0})
    par_pdv[pdv]['nb'] += 1
    par_pdv[pdv]['total'] += c.amount_total
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['point_de_vente', 'nb_commandes', 'chiffre_affaires'])
    for pdv, agg in par_pdv.items():
        writer.writerow([pdv, agg['nb'], round(agg['total'], 2)])
print('RESULTAT:', len(commandes), len(par_pdv))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_PDV_CYC_RAPPORTMENSUEL] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_PDV_CYC_RAPPORTMENSUEL] $COUNT commande(s) du mois passe reparties sur les points de vente - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_PDV_CYC_RAPPORTMENSUEL] Cycle EOM Point de vente TERMINE pour ce mois."
exit 0
