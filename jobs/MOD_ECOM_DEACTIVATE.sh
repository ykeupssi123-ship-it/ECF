#!/bin/bash
# MOD_ECOM_DEACTIVATE - ECF_ECOM_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "website_sale" (Boutique en ligne (eCommerce)).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_ECOM_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "website_sale"
