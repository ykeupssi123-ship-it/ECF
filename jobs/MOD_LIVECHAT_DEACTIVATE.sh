#!/bin/bash
# MOD_LIVECHAT_DEACTIVATE - ECF_LIVECHAT_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "im_livechat" (Chat en direct sur le site web).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_LIVECHAT_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "im_livechat"
