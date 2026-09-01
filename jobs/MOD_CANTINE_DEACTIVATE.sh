#!/bin/bash
# MOD_CANTINE_DEACTIVATE - ECF_CANTINE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "lunch" (Commandes de repas internes).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_CANTINE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "lunch"
