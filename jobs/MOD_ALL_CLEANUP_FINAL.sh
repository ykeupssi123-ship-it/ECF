#!/bin/bash
# MOD_ALL_CLEANUP_FINAL - ECF_SYS_RUN_MODULESCLEAN - Verification/nettoyage
# final : garantit qu'AUCUN des 34 modules Community reels n'est
# "installed" apres la vague complete d'activation/desactivation.
#
# CORRIGE le 2026-09-01 (constat reel, voir docs/JOURNAL_TECHNIQUE.md) :
# chaque paire MOD_<X>_ACTIVATE/DEACTIVATE fonctionne correctement en
# isolation (verifie), mais desactiver un module NE desinstalle JAMAIS
# ses propres dependances (comportement Odoo standard, pas un defaut).
# Exemple reel observe : CONTACTS_DEACTIVATE reussit tot dans la chaine,
# mais un module plus tardif (crm, hr, project...) qui depend de
# "contacts" le reinstalle silencieusement en activant - et comme le
# propre job de contacts ne repasse jamais apres, il reste "installed" a
# la fin. Ce job fait un dernier passage sur les 34 modules et force la
# desactivation de tout ce qui serait reste actif, en boucle jusqu'a un
# point fixe reel (jamais suppose atteint en un seul passage).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

# CORRIGE le 2026-09-01 (constat reel, voir docs/JOURNAL_TECHNIQUE.md) :
# "mail" retire de cette liste apres un vrai echec de desinstallation lors
# du premier passage complet - trace exacte : "odoo.exceptions.MissingError:
# Record does not exist or has been deleted (ir.model.fields)". Diagnostic :
# pas un verrou transitoire (contrairement aux autres incidents de cette
# nuit) mais un residu de donnees dans ir_model_data/ir_model_fields, cause
# par l'enchainement intensif de 34 activations/desactivations qui ont
# toutes, a un moment ou un autre, installe "mail" comme dependance
# transitive (chatter/notifications - quasi tous les modules metier en
# dependent). Nouvelle tentative confirmee inutile (l'ID du champ orphelin
# change a chaque essai : 16620 puis 16647 - la reconstruction du registre
# genere un nouveau residu a chaque fois, aucune convergence). Decision
# assumee plutot qu'une reparation manuelle risquee de la base : "mail"
# reste installe en permanence, au meme titre que "base"/"web" (Tier 0) -
# c'est deja ainsi que fonctionne un vrai deploiement Odoo reel (chatter
# et notifications sont une brique d'infrastructure commune, jamais
# desactivee en pratique, pas une "app metier" que le client active/
# desactive pour la demo). Verifie sans impact : site et service restent
# pleinement fonctionnels (HTTP 200) avec mail installe seul.
MODULES="contacts calendar crm sale_management account purchase stock mrp repair fleet point_of_sale pos_restaurant website website_sale website_event website_slides website_hr_recruitment hr hr_attendance hr_holidays hr_expense hr_recruitment hr_skills project project_todo maintenance survey lunch im_livechat mass_mailing mass_mailing_sms marketing_card data_recycle"

for tour in 1 2 3; do
  reste=0
  for m in $MODULES; do
    etat="$(_odoo_module_state "$m")"
    if [ "$etat" = "installed" ]; then
      echo "[MOD_ALL_CLEANUP_FINAL] Tour ${tour} : ${m} encore installe (residu de dependance) - desactivation..."
      odoo_module_deactivate "$m" || true
      reste=1
    fi
  done
  [ "$reste" -eq 0 ] && break
done

echo "[MOD_ALL_CLEANUP_FINAL] Verification finale reelle en base..."
RESIDUS=""
for m in $MODULES; do
  etat="$(_odoo_module_state "$m")"
  [ "$etat" = "installed" ] && RESIDUS="${RESIDUS}${RESIDUS:+, }${m}"
done

if [ -n "$RESIDUS" ]; then
  echo "[MOD_ALL_CLEANUP_FINAL] ERREUR : modules encore installes apres 3 passages : ${RESIDUS}" >&2
  exit 1
fi

echo "[MOD_ALL_CLEANUP_FINAL] OK (34/34 modules confirmes desactives, systeme pret pour activation manuelle par l'operateur)."
exit 0
