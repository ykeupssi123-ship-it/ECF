#!/bin/bash
# MOD_JOBS_WEB_DEACTIVATE - ECF_JOBS_WEB_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "website_hr_recruitment" (Offres d emploi publiees en ligne).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_JOBS_WEB_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "website_hr_recruitment"
