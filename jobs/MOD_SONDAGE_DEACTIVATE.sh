#!/bin/bash
# MOD_SONDAGE_DEACTIVATE - ECF_SONDAGE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "survey" (Creation et diffusion de sondages).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_SONDAGE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "survey"
