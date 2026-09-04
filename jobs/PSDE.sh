#!/bin/bash
# PSDE - ECF_POS_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "point_of_sale" (Caisse (point de vente)).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_POS_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "point_of_sale"

# CORRIGE le 2026-09-01 (defaut reel trouve en construisant les jobs
# d'illustration Tier 2, voir docs/JOURNAL_TECHNIQUE.md) : "POS_ACTIVE.ok"
# restait present pour toujours une fois cree - un job desactive puis
# jamais reactive continuait a etre lu comme "actif" par tout job Tier 2
# en dependant (IN_COND=POS_ACTIVE). Efface ici le marqueur ACTIVE
# pour que la condition reflete l'etat REEL courant, jamais un historique
# qui ne fait que s'accumuler.
rm -f "${STATE_DIR}/POS_ACTIVE.ok"
