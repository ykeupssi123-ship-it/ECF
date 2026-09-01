#!/bin/bash
# MOD_EVENEMENT_DEACTIVATE - ECF_EVENEMENT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "website_event" (Publication et billetterie d evenements).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_EVENEMENT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "website_event"
