#!/bin/bash
# ECFCVTNT - ECF_VENTE_CYC_NETTOYAGE - 2e job du cycle TFJ Ventes
# (voir ECFCRELVT1 pour le patron complet). IN_COND=TFJ_VENTES_RELANCE_OK
# (jamais avant que la relance du jour ait tourne).
#
# Objectif metier reel : annuler automatiquement les devis (state=draft)
# vieux de plus de 30 jours - nettoyage standard en exploitation ERP
# reelle, evite un pipeline commercial pollue de devis morts. Chaque
# devis annule est note dans le rapport ecrit par ECFCCLOVT1 (job
# suivant), jamais silencieux. OUT_COND=TFJ_VENTES_NETTOYAGE_OK.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

RESULTAT="$(_odoo_shell_exec "
from datetime import datetime, timedelta
Order = env['sale.order']
seuil = datetime.now() - timedelta(days=30)
devis = Order.search([('state', '=', 'draft'), ('create_date', '<', seuil)])
noms = [d.client_order_ref or d.name for d in devis]
devis.action_cancel()
env.cr.commit()
print('RESULTAT:', len(noms))
for n in noms:
    print('ANNULE:', n)
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_VENTE_CYC_NETTOYAGE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_VENTE_CYC_NETTOYAGE] $COUNT devis perimes (>30j) annules."
echo "$RESULTAT" | grep "^ANNULE:"
exit 0
