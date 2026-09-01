#!/bin/bash
# MOD_REPAIR_DEACTIVATE - ECF_REPAIR_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "repair" (Ordres de reparation (SAV/atelier)).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_REPAIR_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "repair"
