#!/bin/bash
# MOD_CONTACTS_DEACTIVATE - ECF_CONTACTS_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "contacts" (Repertoire des contacts (clients, fournisseurs, partenaires)).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_CONTACTS_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "contacts"
