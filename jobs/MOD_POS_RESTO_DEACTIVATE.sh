#!/bin/bash
# MOD_POS_RESTO_DEACTIVATE - ECF_POS_RESTO_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "pos_restaurant" (Extensions caisse pour restauration).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_POS_RESTO_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "pos_restaurant"

# CORRIGE le 2026-09-01 (defaut reel trouve en construisant les jobs
# d'illustration Tier 2, voir docs/JOURNAL_TECHNIQUE.md) : "POS_RESTO_ACTIVE.ok"
# restait present pour toujours une fois cree - un job desactive puis
# jamais reactive continuait a etre lu comme "actif" par tout job Tier 2
# en dependant (IN_COND=POS_RESTO_ACTIVE). Efface ici le marqueur ACTIVE
# pour que la condition reflete l'etat REEL courant, jamais un historique
# qui ne fait que s'accumuler.
rm -f "${STATE_DIR}/POS_RESTO_ACTIVE.ok"
