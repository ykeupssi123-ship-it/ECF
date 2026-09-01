#!/bin/bash
# MOD_COMPTA_DEACTIVATE - ECF_COMPTA_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "account" (Facturation et comptabilite de base).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_COMPTA_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "account"
