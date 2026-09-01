#!/bin/bash
# MOD_CRM_DEACTIVATE - ECF_CRM_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "crm" (Suivi des pistes et opportunites commerciales).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_CRM_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "crm"
