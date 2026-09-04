#!/bin/bash
# ECFBCKAC - ECF_CARTEMKT_BLD_ACTIVATE - Activation reelle du module Odoo
# "marketing_card" (Cartes marketing dynamiques partageables).
#
# Genere le 2026-09-01 a partir du moteur d'activation generique (voir
# lib/commun.sh : odoo_module_activate/odoo_module_deactivate) - meme
# mecanisme pour les 34 modules Community reels du catalogue, jamais
# une simulation : "button_immediate_install()" est le meme code que
# celui declenche par un vrai clic sur "Activer" dans l'interface web,
# execute contre l'instance en cours d'execution (aucun arret de
# service necessaire).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

odoo_module_activate "marketing_card"
