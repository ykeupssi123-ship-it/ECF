#!/bin/bash
# MOD_TODO_DEACTIVATE - ECF_TODO_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "project_todo" (Listes de taches personnelles).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_TODO_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "project_todo"
