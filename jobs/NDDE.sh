#!/bin/bash
# NDDE - ECF_NDF_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "hr_expense" (Notes de frais employes).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_NDF_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "hr_expense"

# CORRIGE le 2026-09-01 (defaut reel trouve en construisant les jobs
# d'illustration Tier 2, voir docs/JOURNAL_TECHNIQUE.md) : "NDF_ACTIVE.ok"
# restait present pour toujours une fois cree - un job desactive puis
# jamais reactive continuait a etre lu comme "actif" par tout job Tier 2
# en dependant (IN_COND=NDF_ACTIVE). Efface ici le marqueur ACTIVE
# pour que la condition reflete l'etat REEL courant, jamais un historique
# qui ne fait que s'accumuler.
rm -f "${STATE_DIR}/NDF_ACTIVE.ok"
