#!/bin/bash
# MOD_ACHAT_DEACTIVATE - ECF_ACHAT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "purchase" (Commandes et appels d offres fournisseurs).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_ACHAT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "purchase"
