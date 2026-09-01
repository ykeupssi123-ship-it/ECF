#!/bin/bash
# MOD_STOCK_DEACTIVATE - ECF_STOCK_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "stock" (Gestion des stocks et logistique).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_STOCK_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "stock"
