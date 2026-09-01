#!/bin/bash
# MOD_RH_DEACTIVATE - ECF_RH_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "hr" (Fiches employes).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_RH_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "hr"
