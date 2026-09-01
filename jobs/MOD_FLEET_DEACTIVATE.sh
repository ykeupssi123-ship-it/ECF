#!/bin/bash
# MOD_FLEET_DEACTIVATE - ECF_FLEET_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "fleet" (Gestion de parc de vehicules).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_FLEET_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "fleet"
