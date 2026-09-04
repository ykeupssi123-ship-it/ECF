#!/bin/bash
# verifier_independance_modules.sh - AJOUTE LE 2026-09-04 (demande
# explicite utilisateur, deja demandee avant - jamais garantie que par
# une verification manuelle ponctuelle jusqu'ici).
#
# Garantit STRUCTURELLEMENT (pas par discipline manuelle) que les
# modules Odoo reels ne sont JAMAIS lies entre eux comme dans
# WAZ_ELK_FACTORY (ou Elasticsearch non installe bloque tous les
# autres services - orchestrator.sh y fait "exit 1" a la premiere
# erreur). Cote ECF, orchestrator.sh isole deja les pannes par SERVICE
# (voir FAILED_SERVICES, jamais un "exit 1" global) - mais CE script
# verifie la cause structurelle : qu'aucun module business n'a, dans
# son IN_COND, une condition produite par un AUTRE module business.
#
# Regle : un SERVICE "module business" (code a 2 lettres, ni SYS, ni un
# groupe d'illustration ILL*) ne peut dependre QUE de :
#   - ODOO_SYSTEME_PRET (ou toute condition produite par SYS)
#   - une condition produite par LUI-MEME (meme SERVICE)
# Exceptions volontaires, PAS des violations :
#   - un groupe d'illustration (ILL1/ILL2/ILL3) qui depend du module
#     business dont il demontre l'usage (ex: EMP1 depend de RH_ACTIVE)
#     - c'est le sujet meme de la demo, pas un couplage artificiel.
#   - SYS qui depend de RY (ECFRCLN attend la fin du recyclage des
#     donnees avant la verification finale) - sequencement interne au
#     Tier 0, jamais une dependance entre deux modules business.
#
# Usage : ./bin/verifier_independance_modules.sh (code 0 = independance
# garantie, code 1 = violation reelle trouvee, detail affiche).
# A relancer apres CHAQUE ajout de job Tier 1 (voir docs/CONVENTION_NOMMAGE.md).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JOBS_CSV="$PROJECT_ROOT/jobs_table.csv"

[ -f "$JOBS_CSV" ] || { echo "ERREUR : $JOBS_CSV introuvable." >&2; exit 1; }

VIOLATIONS="$(awk -F',' '
NR==1 { next }
{
  n++
  jid[n]=$1; incond[n]=$7; svc[n]=$9
  if ($8 != "" && $8 != "NONE") svc_of[$8]=$9
}
END {
  for (i=1;i<=n;i++) {
    s=svc[i]
    is_module = (s != "SYS" && s !~ /^ILL/)
    if (!is_module) continue
    if (incond[i]=="" || incond[i]=="NONE") continue
    split(incond[i], deps, "|")
    for (k in deps) {
      d=deps[k]
      prod=svc_of[d]
      if (prod!="" && prod!=s && prod!="SYS") {
        print jid[i]" (service="s") depend de "d", produit par le service "prod
      }
    }
  }
}
' "$JOBS_CSV")"

MODULE_COUNT="$(awk -F',' 'NR>1 && $9!="SYS" && $9!~/^ILL/ {if(!seen[$9]++) print $9}' "$JOBS_CSV" | wc -l)"

if [ -n "$VIOLATIONS" ]; then
  echo "ECHEC : au moins un module business depend d'un AUTRE module business (couplage a la WEF) :" >&2
  echo "$VIOLATIONS" >&2
  exit 1
fi

echo "OK : les $MODULE_COUNT modules business sont structurellement independants les uns des autres."
echo "(chacun ne depend que de SYS/ODOO_SYSTEME_PRET ou de lui-meme - jamais d'un autre module)."
exit 0
