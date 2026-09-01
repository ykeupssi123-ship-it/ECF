#!/bin/bash
# MOD_MRP_DEACTIVATE - ECF_MRP_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "mrp" (Ordres de fabrication et nomenclatures).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_MRP_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "mrp"
