#!/bin/bash
# MOD_SITE_DEACTIVATE - ECF_SITE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "website" (Constructeur de site web).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_SITE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "website"
