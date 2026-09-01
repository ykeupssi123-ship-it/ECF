#!/bin/bash
# MOD_PRESENCE_DEACTIVATE - ECF_PRESENCE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "hr_attendance" (Pointage des presences).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_PRESENCE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "hr_attendance"
