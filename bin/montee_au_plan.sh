#!/bin/bash
# montee_au_plan.sh - Equivalent fonctionnel du "New Day"/Active Plan
# Control-M, ajoute le 2026-09-04 (demande explicite utilisateur -
# capture d'ecran reelle Control-M, "montee au plan" = un snapshot d'un
# cycle de traitement journalier).
#
# TAXONOMIE REELLE (corrigee le 2026-09-04 - fournie par l'utilisateur,
# vocabulaire d'exploitation bancaire reel, jamais approximee depuis) :
#
#   JOUR (Daily/Intra-day)  : OLTP/temps reel/horaires ouvrés. Declenche
#     automatiquement a frequence fixe (ex. toutes les heures 8h-18h)
#     ou en continu. Cas d'usage : synchronisations d'interfaces,
#     sauvegardes a chaud, teletransmission de flux, alertes temps reel.
#     CE SCRIPT NE GERE PAS CE TYPE : un job JOUR est un job Tier 1
#     classique (OUT_COND=NONE), avec sa PROPRE garde horaire interne
#     (verifie l'heure courante, ne fait rien hors plage) - voir
#     jobs/ECFJVTSV.sh pour l'exemple reel construit.
#   TFJ (Traitements de nuit) : sequence/batchs lourds, declenchee
#     automatiquement a la fermeture (guichets/agences). Chaine
#     d'orchestration de fin de journee : gel des transactions,
#     reconciliations, sauvegardes a froid, calculs de soldes. C'EST CE
#     QUE CE SCRIPT GERE (cadence DAILY ci-dessous) - voir le cycle
#     Ventes (ECFCVTRL->ECFCVTNT->ECFCVTRP, TFJ_VENTES_*).
#   EOD (Echeance metier fin de journee) : horodate (ex. 23h50),
#     quotidien - un MARQUEUR LOGIQUE unique (bascule de la date valeur
#     comptable de J a J+1), jamais toute une chaine de jobs metier.
#     CE SCRIPT NE GERE PAS CE TYPE non plus : un job EOD a son PROPRE
#     minuteur systemd a heure fixe (23:50), pas la fenetre quotidienne
#     00:05 de ce script - voir jobs/ECFCEOD1.sh et
#     setup/installer_service_eod_compta.sh.
#   EOM (Echeance metier fin de mois) : calendaire (dernier jour du
#     mois), mensuelle. Cloture mensuelle : paies, amortissements,
#     arretes comptables, rapports reglementaires. Cadence MONTHLY
#     ci-dessous.
#   ON_DEMAND : evenementiel/ad hoc, manuel (operateur) ou webhook/API,
#     ponctuel. Deja couvert par les jobs Tier 1 pilotes par fichier
#     (rcv/) et par bin/run_now.sh/bin/order_job.sh - rien a ajouter ici.
#
# ROLE REEL de CE script (pas cosmetique) : un traitement cyclique
# (TFJ/EOM) a besoin d'un jalon PERSISTANT et REEL (OUT_COND classique,
# pas NONE) pour garantir qu'il ne tourne qu'UNE FOIS par cycle - mais
# un jalon persistant, une fois marque, resterait marque POUR TOUJOURS,
# empechant le meme traitement de tourner le cycle suivant. Ce script
# est ce qui REMET LE COMPTEUR A ZERO au bon moment (calendrier) :
# jamais l'orchestrateur lui-meme (il ne sait rien du calendrier), un
# processus separe, dedie, explicite.
#
# Pour chaque cycle enregistre dans CYCLE_WINDOWS ci-dessous (cadence
# DAILY = un cycle TFJ, MONTHLY = un cycle EOM - jamais utilise pour
# JOUR ou EOD, voir plus haut) :
#   - Si le cycle n'a pas encore ete "ouvert" pour la periode en cours
#     (jour pour DAILY, mois pour MONTHLY) : archive le jalon terminal
#     de la periode precedente (etat REEL, jamais suppose), efface les
#     jalons de la chaine (window + terminal) pour repartir propre, puis
#     OUVRE la fenetre (marque la condition WINDOW_OPEN) - la chaine de
#     jobs redevient eligible au prochain passage de orchestrator.sh.
#   - Sinon : ne fait rien (idempotent - relancer ce script plusieurs
#     fois le meme jour/mois pour un meme cycle est sans effet apres la
#     premiere fois).
# Ecrit un instantane dat, state/plan/<AAAA-MM-JJ>.csv - LE plan du
# jour, consultable, jamais recalcule retroactivement.
#
# Installe comme minuteur systemd quotidien (voir
# setup/installer_service_montee_au_plan.sh), 00:05 par defaut -
# TOUJOURS avant que quoi que ce soit d'autre ne tourne ce jour-la.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

PLAN_DIR="$STATE_DIR/plan"
PLAN_HISTORY_DIR="$PLAN_DIR/history"
mkdir -p "$PLAN_DIR" "$PLAN_HISTORY_DIR"

TODAY="$(date +%Y-%m-%d)"
TODAY_DOM="$(date +%d)"        # jour du mois (pour MONTHLY/QUARTERLY/YEARLY)
TODAY_MONTH="$(date +%m)"      # mois (pour QUARTERLY/YEARLY)
TODAY_DOW="$(date +%u)"        # jour de semaine ISO, 1=lundi..7=dimanche (pour WEEKLY)
MONTH_KEY="$(date +%Y-%m)"
WEEK_KEY="$(date +%G-W%V)"     # annee-semaine ISO (pour WEEKLY)
QUARTER_NUM=$(( (10#$TODAY_MONTH - 1) / 3 + 1 ))
QUARTER_KEY="$(date +%Y)-Q${QUARTER_NUM}"
YEAR_KEY="$(date +%Y)"

# Registre des cycles connus - AJOUTER UNE LIGNE ICI pour chaque
# nouveau cycle (jamais devine, jamais implicite) :
#   [CONDITION_WINDOW_OPEN]="CADENCE:CONDITION_TERMINALE:LIBELLE"
# CADENCE : DAILY (=TFJ, tous les jours), WEEKLY (=EOW, le samedi -
# "apres la fermeture du vendredi"), MONTHLY (=EOM, le 1er du mois -
# "apres la cloture du mois precedent", meme raisonnement que DAILY qui
# ouvre a 00:05 pour LE JOUR QUI VIENT DE SE TERMINER), QUARTERLY
# (=EOQ, le 1er jour d'un nouveau trimestre), YEARLY (=EOY, le 1er
# janvier). JAMAIS utilise pour JOUR/NRT/EOD/CUTOFF (voir taxonomie
# plus haut - mecanismes differents, garde horaire interne ou minuteur
# dedie a heure fixe).
declare -A CYCLE_WINDOWS=(
  [TFJ_VENTES_WINDOW_OPEN]="DAILY:TFJ_VENTES_TERMINE:Ventes - cloture quotidienne (relance devis, nettoyage, rapport)"
  [PURGE_ARC_WINDOW_OPEN]="MONTHLY:PURGE_ARC_TERMINE:Systeme - archivage a froid des fichiers arc/ de plus de 90 jours"
  # Ajoutes le 2026-09-04 (chantier "anticipation" demande par l'utilisateur -
  # construction des operations HAUTE priorite du catalogue avec leurs
  # dependances et leur calendrier reel) :
  [TFJ_COMPTA_WINDOW_OPEN]="DAILY:TFJ_COMPTA_TERMINE:Comptabilite - cloture quotidienne (reconciliation bancaire, relance factures impayees)"
  [COMPTA_EOM_WINDOW_OPEN]="MONTHLY:COMPTA_EOM_TERMINE:Comptabilite - cloture comptable mensuelle"
  [COMPTA_EOQ_WINDOW_OPEN]="QUARTERLY:COMPTA_EOQ_TERMINE:Comptabilite - declaration TVA trimestrielle"
  [VENTES_EOM_WINDOW_OPEN]="MONTHLY:VENTES_EOM_TERMINE:Ventes - cloture commerciale mensuelle (objectifs, commissions)"
  # Ajoutes le 2026-09-05 (2e lot du meme chantier "anticipation" -
  # les 8 dernieres operations HAUTE priorite du catalogue) :
  [TFJ_CRM_WINDOW_OPEN]="DAILY:TFJ_CRM_TERMINE:CRM - relance quotidienne des pistes stagnantes (>7j)"
  [TFJ_ACHAT_WINDOW_OPEN]="DAILY:TFJ_ACHAT_TERMINE:Achat - reapprovisionnement automatique nocturne"
  [TFJ_STOCK_WINDOW_OPEN]="DAILY:TFJ_STOCK_TERMINE:Stock - valorisation nocturne"
  [TFJ_PDV_WINDOW_OPEN]="DAILY:TFJ_PDV_TERMINE:Point de vente - cloture de caisse quotidienne"
  [TFJ_RH_WINDOW_OPEN]="DAILY:TFJ_RH_TERMINE:RH - alerte quotidienne des fins de contrat proches"
  [PRESENCES_EOM_WINDOW_OPEN]="MONTHLY:PRESENCES_EOM_TERMINE:Presences - calcul des heures travaillees mensuel"
  [PROJETS_EOM_WINDOW_OPEN]="MONTHLY:PROJETS_EOM_TERMINE:Projets - facturation au temps passe mensuelle"
)

PLAN_FILE="$PLAN_DIR/${TODAY}.csv"
[ -f "$PLAN_FILE" ] || echo "DATE,CONDITION_WINDOW,CADENCE,STATUT,LIBELLE" > "$PLAN_FILE"

for WINDOW_COND in "${!CYCLE_WINDOWS[@]}"; do
  IFS=':' read -r CADENCE TERMINAL_COND LIBELLE <<< "${CYCLE_WINDOWS[$WINDOW_COND]}"

  case "$CADENCE" in
    DAILY)
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${TODAY}"
      ;;
    WEEKLY)
      if [ "$TODAY_DOW" != "6" ]; then
        echo "$TODAY,$WINDOW_COND,$CADENCE,PAS_DU_JOUR,$LIBELLE" >> "$PLAN_FILE"
        continue
      fi
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${WEEK_KEY}"
      ;;
    MONTHLY)
      if [ "$TODAY_DOM" != "01" ]; then
        echo "$TODAY,$WINDOW_COND,$CADENCE,PAS_DU_JOUR,$LIBELLE" >> "$PLAN_FILE"
        continue
      fi
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${MONTH_KEY}"
      ;;
    QUARTERLY)
      if [ "$TODAY_DOM" != "01" ] || [[ ! "$TODAY_MONTH" =~ ^(01|04|07|10)$ ]]; then
        echo "$TODAY,$WINDOW_COND,$CADENCE,PAS_DU_JOUR,$LIBELLE" >> "$PLAN_FILE"
        continue
      fi
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${QUARTER_KEY}"
      ;;
    YEARLY)
      if [ "$TODAY_DOM" != "01" ] || [ "$TODAY_MONTH" != "01" ]; then
        echo "$TODAY,$WINDOW_COND,$CADENCE,PAS_DU_JOUR,$LIBELLE" >> "$PLAN_FILE"
        continue
      fi
      DUE_MARK="$PLAN_DIR/.ouvert_${WINDOW_COND}_${YEAR_KEY}"
      ;;
    *)
      echo "[montee_au_plan] ERREUR : cadence inconnue '$CADENCE' pour $WINDOW_COND (verifier CYCLE_WINDOWS)." >&2
      continue
      ;;
  esac

  if [ -f "$DUE_MARK" ]; then
    echo "[montee_au_plan] $WINDOW_COND deja ouvert pour cette periode - rien a faire."
    echo "$TODAY,$WINDOW_COND,$CADENCE,DEJA_OUVERT,$LIBELLE" >> "$PLAN_FILE"
    continue
  fi

  # Archive le jalon terminal du cycle precedent (etat REEL) avant de
  # l'effacer - jamais une perte silencieuse d'information.
  if [ -f "$STATE_DIR/${TERMINAL_COND}.ok" ]; then
    cp "$STATE_DIR/${TERMINAL_COND}.ok" "$PLAN_HISTORY_DIR/${TERMINAL_COND}_$(date +%Y%m%d_%H%M%S).ok"
    rm -f "$STATE_DIR/${TERMINAL_COND}.ok"
  fi
  rm -f "$STATE_DIR/${WINDOW_COND}.ok"

  mark_done "$WINDOW_COND"
  touch "$DUE_MARK"
  echo "[montee_au_plan] $WINDOW_COND OUVERT ($LIBELLE) - la chaine redevient eligible au prochain ./orchestrator.sh."
  echo "$TODAY,$WINDOW_COND,$CADENCE,OUVERT,$LIBELLE" >> "$PLAN_FILE"
done

echo "[montee_au_plan] Plan du jour ecrit : $PLAN_FILE"
exit 0
