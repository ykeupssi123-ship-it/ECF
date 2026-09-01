#!/bin/bash
# MOD_EMAILMKT_DEACTIVATE - ECF_EMAILMKT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "mass_mailing" (Campagnes email marketing).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_EMAILMKT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "mass_mailing"
