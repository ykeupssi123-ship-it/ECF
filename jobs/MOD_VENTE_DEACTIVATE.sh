#!/bin/bash
# MOD_VENTE_DEACTIVATE - ECF_VENTE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "sale_management" (Devis, commandes et facturation client).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_VENTE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "sale_management"
