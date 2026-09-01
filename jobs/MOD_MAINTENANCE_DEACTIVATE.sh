#!/bin/bash
# MOD_MAINTENANCE_DEACTIVATE - ECF_MAINTENANCE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "maintenance" (Suivi de maintenance des equipements).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_MAINTENANCE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "maintenance"
