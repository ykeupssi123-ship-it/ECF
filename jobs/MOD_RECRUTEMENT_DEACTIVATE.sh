#!/bin/bash
# MOD_RECRUTEMENT_DEACTIVATE - ECF_RECRUTEMENT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "hr_recruitment" (Pipeline de recrutement).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_RECRUTEMENT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "hr_recruitment"
