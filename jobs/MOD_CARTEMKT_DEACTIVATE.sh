#!/bin/bash
# MOD_CARTEMKT_DEACTIVATE - ECF_CARTEMKT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "marketing_card" (Cartes marketing dynamiques partageables).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_CARTEMKT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "marketing_card"
