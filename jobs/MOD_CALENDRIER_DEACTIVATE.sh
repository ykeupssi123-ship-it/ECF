#!/bin/bash
# MOD_CALENDRIER_DEACTIVATE - ECF_CALENDRIER_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "calendar" (Agenda partage et rendez-vous).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_CALENDRIER_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "calendar"
