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
