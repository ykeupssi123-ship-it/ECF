#!/bin/bash
# MOD_DISCUSS_DEACTIVATE - ECF_DISCUSS_BLD_DEACTIVATE - Desactivation reelle du module
# Odoo "mail" (Messagerie interne et notifications).
#
# Genere le 2026-09-01 - voir lib/commun.sh (odoo_module_deactivate).
# Reversible : reactivable a tout moment via MOD_DISCUSS_ACTIVATE.
#
# LIMITE CONNUE (2026-09-01, voir docs/JOURNAL_TECHNIQUE.md) : "mail" est
# une dependance transitive de la quasi-totalite des modules metier
# (chatter/notifications) - une fois qu'un autre module a ete installe
# puis desinstalle en laissant des extensions de champ sur les modeles de
# mail, ce job peut echouer avec "MissingError: Record does not exist"
# (residu ir_model_fields). MOD_ALL_CLEANUP_FINAL.sh traite deja "mail"
# comme une brique d'infrastructure permanente (comme base/web) plutot
# que comme un module a desactiver systematiquement - ce job individuel
# reste fourni pour un usage isole (base fraiche, aucun autre module
# jamais installe), pas garanti apres une longue session de tests.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_deactivate "mail"
