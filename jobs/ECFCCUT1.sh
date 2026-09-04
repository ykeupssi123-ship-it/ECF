#!/bin/bash
# ECFCCUT1 - ECF_ACHAT_CUTOFF_ORDRES - Marqueur CUTOFF reel (voir
# bin/montee_au_plan.sh pour la taxonomie complete). Meme famille
# structurelle qu'un marqueur EOD (voir ECFCEOD1.sh) - horodate, pas
# une chaine - mais une heure LEGALE/METIER STRICTE propre a UN FLUX
# (ici : commandes fournisseurs), pas la bascule comptable globale.
#
# Role reel : toute commande fournisseur creee AVANT l'heure de cutoff
# (15h par defaut) porte la date de valeur du jour (J) ; toute commande
# creee APRES bascule automatiquement sur J+1. Ce job ne cree aucune
# commande lui-meme - il ecrit la decision (J ou J+1) dans un marqueur
# que les futurs jobs de creation de commande (ECFRAHPO et ses
# successeurs) pourront consulter, exactement comme un vrai cutoff
# RTGS/SWIFT ne traite pas les flux, il fixe la regle qui s'applique a
# eux. OUT_COND=NONE, comme un job JOUR - invoque a chaque passage de
# l'orchestrateur (15 min), idempotent par construction (recalcule la
# regle a chaque fois, ne fait jamais de suppose entre deux passages).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

HEURE_CUTOFF=15
HEURE_COURANTE="$(date +%H | sed 's/^0//')"
MARQUEUR="$STATE_DIR/cutoff_achat_date_valeur.txt"

if [ "$HEURE_COURANTE" -lt "$HEURE_CUTOFF" ]; then
  DATE_VALEUR="$(date +%Y-%m-%d)"
  STATUT="AVANT_CUTOFF"
else
  DATE_VALEUR="$(date -d tomorrow +%Y-%m-%d)"
  STATUT="APRES_CUTOFF"
fi

ANCIENNE="$([ -f "$MARQUEUR" ] && cat "$MARQUEUR" || echo "(aucune)")"
echo "$DATE_VALEUR" > "$MARQUEUR"

if [ "$ANCIENNE" = "$DATE_VALEUR" ]; then
  echo "[ECF_ACHAT_CUTOFF_ORDRES] $STATUT (${HEURE_COURANTE}h, seuil ${HEURE_CUTOFF}h) - date de valeur inchangee ($DATE_VALEUR)."
else
  echo "[ECF_ACHAT_CUTOFF_ORDRES] $STATUT (${HEURE_COURANTE}h, seuil ${HEURE_CUTOFF}h) - date de valeur : $ANCIENNE -> $DATE_VALEUR."
fi
exit 0
