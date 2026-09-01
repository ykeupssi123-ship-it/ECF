#!/bin/bash
# MOD_PRESENCE_DEACTIVATE - ECF_PRESENCE_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "hr_attendance" (Pointage des presences).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_PRESENCE_ACTIVATE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "hr_attendance"

# CORRIGE le 2026-09-01 (defaut reel trouve en construisant les jobs
# d'illustration Tier 2, voir docs/JOURNAL_TECHNIQUE.md) : "PRESENCE_ACTIVE.ok"
# restait present pour toujours une fois cree - un job desactive puis
# jamais reactive continuait a etre lu comme "actif" par tout job Tier 2
# en dependant (IN_COND=PRESENCE_ACTIVE). Efface ici le marqueur ACTIVE
# pour que la condition reflete l'etat REEL courant, jamais un historique
# qui ne fait que s'accumuler.
rm -f "${STATE_DIR}/PRESENCE_ACTIVE.ok"
