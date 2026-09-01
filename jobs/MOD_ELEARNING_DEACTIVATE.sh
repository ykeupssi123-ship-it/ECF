#!/bin/bash
# MOD_ELEARNING_DEACTIVATE - ECF_ELEARNING_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "website_slides" (Plateforme de formation en ligne).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_ELEARNING_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "website_slides"
