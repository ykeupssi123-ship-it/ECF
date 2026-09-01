#!/bin/bash
# MOD_SMSMKT_DEACTIVATE - ECF_SMSMKT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "mass_mailing_sms" (Campagnes SMS marketing).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_SMSMKT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "mass_mailing_sms"
