#!/bin/bash
# MOD_RECYCLAGE_DEACTIVATE - ECF_RECYCLAGE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "data_recycle" (Detection et archivage des donnees perimees).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_RECYCLAGE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "data_recycle"
