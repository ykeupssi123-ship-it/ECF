#!/bin/bash
# =====================================================================
#  WAZ_ELK_FACTORY (237 jobs) - ORCHESTRATEUR (ordonnanceur)
#  Meme moteur que wazuh_factory_2/orchestrator.sh : lit jobs_table.csv,
#  resout les dependances (IN_COND/OUT_COND) et execute les jobs un a
#  un, dans l'ordre permis par les dependances.
#  Ne contient AUCUNE donnee en dur : tout vient de vars.conf.
#
#  DEUX NIVEAUX DE FILTRAGE :
#   1) ROLE (ELK_HOST ou AGENT_HOST) - le "grand" choix de la machine.
#      ELK_HOST = VM1 (Elasticsearch/Logstash/Kibana/Wazuh, monolithique).
#      AGENT_HOST = TOUTE AUTRE machine (VM2, ou un hote Linux
#      supplementaire) qui fait tourner un ou plusieurs agents.
#   2) AGENT_COMPONENTS (liste, uniquement si ROLE=AGENT_HOST) - QUELS
#      agents tournent sur CETTE machine precise, parmi FILEBEAT,
#      METRICBEAT, WAZUH_AGENT. Les 3 peuvent cohabiter sur la MEME
#      machine (c'est le cas de VM2 par defaut) OU etre repartis sur
#      des machines differentes (c'est aussi possible - a vous de
#      choisir par machine via AGENT_COMPONENTS dans vars.conf).
#
#  ISOLATION DE PANNE PAR SERVICE (corrige le 2026-09-04, incident reel
#  ERP_CRM_FACTORY) : ce moteur vient de WAZ_ELK_FACTORY tel quel, ou le
#  comportement d'origine etait "arret au premier echec, deliberement" -
#  pertinent LA-BAS car les jobs y forment une chaine quasi-lineaire
#  (chaque service depend reellement du precedent). Ce n'est PLUS vrai
#  ici : les 34 modules Odoo (colonne SERVICE, jobs_table.csv) sont deja
#  INDEPENDANTS les uns des autres (meme IN_COND=ODOO_SYSTEME_PRET pour
#  tous, jamais chaines entre eux) - pourtant un echec sur UN SEUL
#  module arretait TOUT l'orchestrateur, y compris les 33 autres modules
#  sans aucun lien avec celui en echec. Corrige : un echec de job marque
#  desormais UNIQUEMENT son SERVICE comme en echec - les autres jobs de
#  ce meme service sont sautes (pas de suite possible sur une base
#  cassee), mais TOUS LES AUTRES SERVICES continuent d'etre tentes
#  normalement. Un job qui depend REELLEMENT (via IN_COND) d'un service
#  en echec reste bloque automatiquement par le mecanisme de dependance
#  deja existant - rien a ajouter pour ce cas, il fonctionnait deja.
#  Code de sortie final : 1 si au moins un service a echoue (rien de
#  silencieux), 0 sinon - mais seulement APRES avoir laisse sa chance a
#  chaque service independant. Chaque machine (VM1, VM2, chaque hote
#  d'agent) execute SA PROPRE instance de cet orchestrateur : un echec
#  sur une machine n'arrete jamais les autres, qui tournent
#  independamment.
#
#  A LA FIN (succes OU echec), un rapport est toujours ecrit dans
#  state/RAPPORT_EXECUTION.txt : jobs termines, job en echec le cas
#  echeant, jobs jamais atteints, scripts absents.
# =====================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="$SCRIPT_DIR/vars.conf"
source "$VARS_FILE"
source "$SCRIPT_DIR/lib/commun.sh"

mkdir -p "$STATE_DIR" "$LOG_DIR" "$WORK_TMP_DIR"
TS=$(date +%Y%m%d_%H%M%S)
RUN_LOG="$LOG_DIR/orchestrator_${TS}.log"
JOBS_CSV="$SCRIPT_DIR/jobs_table.csv"
REPORT_FILE="$STATE_DIR/RAPPORT_EXECUTION.txt"

# HISTORIQUE PAR JOB (ajoute le 2026-08-12) : un .ok ne garde que la
# DERNIERE reussite (ecrase a chaque re-execution) - insuffisant pour
# repondre a "ce job a tourne 10 fois aujourd'hui, je veux voir chacune
# des 10 sorties". Desormais, CHAQUE execution reelle (pas les jobs
# sautes car deja .ok) laisse une trace : une ligne dans le registre
# HISTORY_LEDGER (jamais reecrite, uniquement ajoutee) + un fichier de
# log dedie a CETTE execution precise dans HISTORY_DIR/<JOB_ID>/. Voir
# bin/view_history.sh a la racine pour consulter.
HISTORY_DIR="$STATE_DIR/history"
HISTORY_LEDGER="$STATE_DIR/JOBS_HISTORY.csv"
mkdir -p "$HISTORY_DIR"
# En-tete corrigee le 2026-09-04 (DURATION_SEC manquait deja de l'en-tete
# alors que les lignes OK/ECHEC l'ecrivaient depuis le 2026-08-12 - jamais
# bloquant pour bin/view_history.sh, qui lit par position, mais trompeur a
# la lecture directe du fichier). PATH_TOUCHED ajoutee le meme jour
# (pratique reelle CBS/SGABS : savoir quel chemin $ECFOP exact a ete
# touche par quelle execution, sans devoir grep les scripts). Colonne
# alimentee UNIQUEMENT si le job ecrit dans $ECF_JOB_PATHS_FILE (variable
# exportee avant chaque lancement, voir plus bas) - aucun job existant
# n'y ecrit aujourd'hui, la colonne reste vide jusqu'aux premiers vrais
# jobs d'import/export sur $ECFOP.
[ -f "$HISTORY_LEDGER" ] || echo "TIMESTAMP,JOB_ID,JOB_NAME,RESULT,LOG_FILE,DURATION_SEC,PATH_TOUCHED" > "$HISTORY_LEDGER"

# Purge automatique de l'historique perime (SYSOUT), ajoutee le
# 2026-08-12 - equivalent fonctionnel de l'expiration d'une SYSOUT
# JCL/mainframe. Retention pilotee par HISTORY_RETENTION_DAYS (vars.conf,
# 7 jours par defaut en contexte demo). Silencieuse et rapide : ne doit
# jamais bloquer le demarrage meme si le script est absent ou echoue.
if [ -x "$SCRIPT_DIR/maintenance/MNT_purge_historique.sh" ]; then
  "$SCRIPT_DIR/maintenance/MNT_purge_historique.sh" >> "$RUN_LOG" 2>&1 || true
fi

# ETAT VIVANT (EN_COURS), ajoute le 2026-08-12 : jusqu'ici, l'etat d'un
# job n'etait connu qu'APRES coup (OK/ECHEC dans l'historique). Aucun
# moyen, depuis un autre terminal pendant que l'orchestrateur tourne,
# de savoir "il en est ou la MAINTENANT". Equivalent fonctionnel du
# statut EXECUTING/ACTIVE chez Control-M/Autosys/JES : un marqueur
# .running existe UNIQUEMENT pendant l'execution reelle, contient le
# PID reel du job, et disparait des que le job se termine (succes,
# echec, ou interruption via le trap ci-dessous). Un marqueur dont le
# PID ne repond plus = execution precedente interrompue brutalement
# (crash, kill -9, coupure electrique) - jamais interprete comme "en
# cours" sans verification du PID. Voir bin/monitoring.sh a la racine.
RUNNING_DIR="$STATE_DIR/RUNNING"
mkdir -p "$RUNNING_DIR"
ORCH_MARK="$RUNNING_DIR/_ORCHESTRATEUR.running"
echo "$(date -Iseconds),$$" > "$ORCH_MARK"
# CORRIGE LE 2026-09-04 (avec le passage au parallelisme reel) : avant,
# au plus UN job tournait a la fois, son marqueur .running vivait dans
# une variable du processus PARENT ($CURRENT_JOB_MARK). Desormais
# PLUSIEURS jobs tournent en meme temps, chacun dans son propre
# sous-shell (voir run_job_async) - le parent n'a plus aucune variable
# unique a nettoyer. Balayage de TOUT $RUNNING_DIR/*.running a la
# place : sans risque, un marqueur encore present a ce stade (sortie de
# l'orchestrateur, normale ou interrompue) est par definition perime -
# bin/monitoring.sh verifie de toute facon le PID reel avant d'afficher
# quoi que ce soit comme "en cours" (voir plus haut).
cleanup_running(){ rm -f "$ORCH_MARK" "$RUNNING_DIR"/*.running 2>/dev/null || true; }

log(){ echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$RUN_LOG"; }
mkdir -p "$STATE_DIR/HELD"

# PARALLELISME REEL PAR VAGUES (ajoute le 2026-09-04, demande explicite
# utilisateur - capture d'ecran Control-M reelle montrant plusieurs
# chaines de jobs actives simultanement). AVANT : la boucle principale
# lancait un job en arriere-plan uniquement pour recuperer son PID, puis
# l'attendait IMMEDIATEMENT (wait) avant de passer a la ligne suivante -
# strictement sequentiel, meme entre services deja prouves independants
# (bin/verifier_independance_modules.sh). MAINTENANT : chaque passe lance
# TOUS les jobs prets de cette passe en parallele (voir run_job_async
# plus bas et la boucle principale), plafonnes a MAX_PARALLEL_JOBS
# (vars.conf) simultanes.
#
# CONSEQUENCE STRUCTURELLE : un sous-shell lance en arriere-plan (&) ne
# peut PAS modifier les variables du processus PARENT (contrairement a
# l'ancien code, ou le "wait" synchrone gardait tout dans le MEME
# processus). FAILED_SERVICES et RAN_THIS_RUN, auparavant des tableaux
# associatifs en memoire, deviennent donc des repertoires sur disque -
# le seul mecanisme qui survit a la frontiere du sous-shell. Purges (rm
# -rf puis mkdir) au DEBUT de chaque run pour repartir d'un etat propre,
# jamais purges a la fin (utile pour inspecter apres coup en cas de
# question sur un run precedent).
RUN_TMP_DIR="$STATE_DIR/run_tmp"
FAILED_SERVICES_DIR="$RUN_TMP_DIR/failed_services"
RAN_THIS_RUN_DIR="$RUN_TMP_DIR/ran_this_run"
FAILED_JOBS_LOG_FILE="$RUN_TMP_DIR/failed_jobs_log.txt"
rm -rf "$RUN_TMP_DIR"
mkdir -p "$FAILED_SERVICES_DIR" "$RAN_THIS_RUN_DIR"
: > "$FAILED_JOBS_LOG_FILE"

# Plafond de jobs simultanes au sein d'une meme vague - une VM de demo
# ne doit pas se retrouver avec 40 "odoo-bin shell" lances a l'identique.
# Valeur par defaut si absente de vars.conf (retro-compatibilite).
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-6}"

# Ecrit le rapport final, quelle que soit l'issue (succes, echec, Ctrl+C).
write_report() {
  {
    echo "=================================================="
    echo " RAPPORT D'EXECUTION - ${PROJECT_NAME:-WAZ_ELK_FACTORY}"
    echo "=================================================="
    echo "Date        : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Machine     : $(hostname 2>/dev/null || echo inconnue)"
    echo "ROLE        : $ROLE"
    [ "$ROLE" = "AGENT_HOST" ] && echo "Composants  : ${AGENT_COMPONENTS:-(aucun)}"
    echo "Log complet : $RUN_LOG"
    echo ""
    FAILED_COUNT="$(find "$FAILED_SERVICES_DIR" -type f 2>/dev/null | wc -l)"
    if [ "$FAILED_COUNT" -gt 0 ]; then
      echo "RESULTAT : ${FAILED_COUNT} SERVICE(S) EN ECHEC (les autres services independants ont ete tentes jusqu'au bout - voir isolation de panne par service, en-tete du script)"
      echo "Services en echec : $(ls "$FAILED_SERVICES_DIR" 2>/dev/null | tr '\n' ' ')"
      echo ""
      echo "--- Jobs en echec ---"
      cat "$FAILED_JOBS_LOG_FILE" 2>/dev/null
    else
      echo "RESULTAT : TERMINE SANS ECHEC (tous les jobs prets pour ce ROLE/composants ont ete rejoues jusqu'a stabilisation)"
    fi
    echo ""
    echo "--- JOBS TERMINES AVEC SUCCES (${STATE_DIR}/*.ok) ---"
    if ls "$STATE_DIR"/*.ok >/dev/null 2>&1; then
      ls "$STATE_DIR"/*.ok | xargs -n1 basename | sed 's/\.ok$//'
    else
      echo "(aucun)"
    fi
    echo ""
    echo "--- JOBS JAMAIS ATTEINTS (dependance non satisfaite, ou apres l'echec) ---"
    NOT_REACHED=0
    while IFS=',' read -r JOB_ID JOB_NAME JOB_ROLE COMPONENT SCRIPT_FILE DESC IN_COND OUT_COND SERVICE; do
      [ "$JOB_ID" = "JOB_ID" ] && continue
      [ -z "${JOB_ID:-}" ] && continue
      [[ "$JOB_ROLE" != "$ROLE" && "$JOB_ROLE" != "ALL" ]] && continue
      if [ "$ROLE" = "AGENT_HOST" ]; then
        component_enabled "$COMPONENT" || continue
      fi
      # OUT_COND=NONE (jobs repetables, ajoute le 2026-09-04) : "jamais
      # atteint" n'a pas de sens pour un job sans jalon permanent - ne
      # figure ici que s'il n'a pas tourne DANS CETTE execution.
      if [ "$OUT_COND" = "NONE" ]; then
        [ -f "$RAN_THIS_RUN_DIR/$JOB_ID" ] && continue
        echo "$JOB_ID ($JOB_NAME)"
        NOT_REACHED=1
        continue
      fi
      job_done "$OUT_COND" && continue
      echo "$JOB_ID ($JOB_NAME)"
      NOT_REACHED=1
    done < "$JOBS_CSV"
    [ $NOT_REACHED -eq 0 ] && echo "(aucun - tout ce qui concerne ce ROLE/composants est termine)"
    echo "=================================================="
  } > "$REPORT_FILE"
  log "Rapport ecrit dans $REPORT_FILE"
}
trap 'cleanup_running; write_report' EXIT

log "=== Demarrage orchestrateur $PROJECT_NAME - ROLE=$ROLE - PROJET=$PROJECT_NAME ==="

if [ "$ROLE" = "ELK_HOST" ] && [ -z "${FACTORY_HOST_IP:-}" ]; then
  log "ATTENTION : FACTORY_HOST_IP est vide dans vars.conf. Certains jobs reseau (LS_008, LS_009, LS_020...) en ont besoin."
fi
if [ "$ROLE" = "AGENT_HOST" ]; then
  if [ -z "${FACTORY_HOST_IP:-}" ]; then
    log "ERREUR : FACTORY_HOST_IP doit etre renseigne dans vars.conf (IP de la VM ELK_HOST)."
  fi
  if [ -z "${AGENT_COMPONENTS:-}" ]; then
    log "ERREUR : AGENT_COMPONENTS est vide dans vars.conf. Choisissez FILEBEAT et/ou METRICBEAT et/ou WAZUH_AGENT (ex: FILEBEAT,METRICBEAT,WAZUH_AGENT)."
  else
    log "Composants actifs sur cette machine : $AGENT_COMPONENTS"
  fi
fi

# run_job_async() : unite d'execution AUTO-SUFFISANTE pour un job reel
# (jamais utilisee pour SAUTE_CONFIG, gere ailleurs de facon synchrone
# et quasi instantanee - inutile de la paralleliser). Concue pour
# tourner DANS un sous-shell (appelee avec "&") : fait tout ce que
# l'ancien code faisait juste apres son "wait" synchrone - execution,
# log dedie, marquage .ok, ligne HISTORY_LEDGER, notification d'echec -
# entierement a partir de ses propres arguments et de fichiers sur
# disque, jamais une variable du parent qui ne survivrait pas a la
# frontiere du sous-shell.
#
# SEULE CHOSE VOLONTAIREMENT ABANDONNEE ICI par rapport a l'ancien code :
# le "cat $JOB_LOG >> $RUN_LOG" qui recopiait la sortie complete du job
# dans le log combine de l'orchestrateur. Sous vraie concurrence,
# plusieurs sous-shells ecrivant simultanement un CONTENU MULTI-LIGNES
# dans le MEME fichier ("cat ... >>") ne sont PAS garantis atomiques
# (contrairement a une ligne UNIQUE de HISTORY_LEDGER, protegee par
# PIPE_BUF) - risque reel d'entrelacement/corruption du log combine.
# Le log dedie a CETTE execution (JOB_LOG, sous HISTORY_DIR/<JOB_ID>/)
# reste la source complete et fiable, deja consultable via
# ./bin/view_history.sh - $RUN_LOG garde seulement les lignes de statut
# courtes (deja ecrites via log(), elles, sures sous PIPE_BUF).
run_job_async() {
  local JOB_ID="$1" JOB_NAME="$2" SCRIPT_FILE="$3" DESC="$4" OUT_COND="$5" SERVICE="$6"
  local SCRIPT_PATH="$SCRIPT_DIR/jobs/$SCRIPT_FILE"

  check_dev_null
  log "--- $JOB_ID ($JOB_NAME) : $DESC ---"
  local JOB_TS
  JOB_TS=$(date +%Y%m%d_%H%M%S_%N)
  mkdir -p "$HISTORY_DIR/$JOB_ID"
  local JOB_LOG="$HISTORY_DIR/$JOB_ID/${JOB_TS}.log"
  local JOB_PATHS_FILE="$HISTORY_DIR/$JOB_ID/${JOB_TS}.paths"
  export ECF_JOB_PATHS_FILE="$JOB_PATHS_FILE"

  # Meme correctif "< /dev/null" que l'ancien code (incident reel
  # ERP_CRM_FACTORY, 2026-09-01) : ici chaque job a de toute facon son
  # propre sous-shell, mais le "< /dev/null" reste necessaire pour la
  # meme raison (empecher un job de voler un octet sur un descripteur
  # partage, par prudence).
  local JOB_START_EPOCH
  JOB_START_EPOCH=$(date +%s)
  bash "$SCRIPT_PATH" > "$JOB_LOG" 2>&1 < /dev/null &
  local JOB_PID=$!
  local CURRENT_JOB_MARK="$RUNNING_DIR/${JOB_ID}.running"
  echo "$(date -Iseconds),$JOB_PID,$JOB_NAME" > "$CURRENT_JOB_MARK"
  wait "$JOB_PID"
  local JOB_EXIT=$?
  rm -f "$CURRENT_JOB_MARK"

  local JOB_DURATION_SEC=$(( $(date +%s) - JOB_START_EPOCH ))
  local PATH_TOUCHED=""
  if [ -s "$JOB_PATHS_FILE" ]; then
    PATH_TOUCHED="$(paste -sd';' "$JOB_PATHS_FILE")"
  fi

  if [ $JOB_EXIT -eq 0 ]; then
    mark_done "$OUT_COND"
    echo "$(date -Iseconds),$JOB_ID,$JOB_NAME,OK,$JOB_LOG,$JOB_DURATION_SEC,$PATH_TOUCHED" >> "$HISTORY_LEDGER"
    log "$JOB_ID -> OK ($OUT_COND) [historique: ./bin/view_history.sh $JOB_ID]"
  else
    echo "$(date -Iseconds),$JOB_ID,$JOB_NAME,ECHEC,$JOB_LOG,$JOB_DURATION_SEC,$PATH_TOUCHED" >> "$HISTORY_LEDGER"
    local SVC_LABEL="${SERVICE:-(aucun)}"
    log "$JOB_ID -> ECHEC (service '$SVC_LABEL'). Voir $JOB_LOG (ou ./bin/view_history.sh $JOB_ID). Ce service s'arrete, les autres services independants continuent."
    if [ -n "${SERVICE:-}" ]; then
      touch "$FAILED_SERVICES_DIR/$SERVICE"
    fi
    echo "${JOB_ID} (${JOB_NAME}, service ${SVC_LABEL}) - voir ${JOB_LOG}" >> "$FAILED_JOBS_LOG_FILE"
    # Alerte email (bin/notifier.sh, ajoute le 2026-08-12) - ne bloque et
    # ne casse JAMAIS l'orchestrateur, meme si l'envoi echoue ou si
    # NOTIF_ENABLED n'est pas configure.
    if [ -x "$SCRIPT_DIR/bin/notifier.sh" ]; then
      "$SCRIPT_DIR/bin/notifier.sh" "$JOB_ID" "$JOB_NAME" "ECHEC" "$JOB_LOG" >> "$RUN_LOG" 2>&1 || true
    fi
  fi
}

MAX_PASSES=30
RUNNING_COUNT=0
for pass in $(seq 1 $MAX_PASSES); do
  progressed=0
  while IFS=',' read -r JOB_ID JOB_NAME JOB_ROLE COMPONENT SCRIPT_FILE DESC IN_COND OUT_COND SERVICE; do
    [ "$JOB_ID" = "JOB_ID" ] && continue
    [ -z "${JOB_ID:-}" ] && continue
    [[ "$JOB_ROLE" != "$ROLE" && "$JOB_ROLE" != "ALL" ]] && continue
    if [ "$ROLE" = "AGENT_HOST" ]; then
      component_enabled "$COMPONENT" || continue
    fi
    job_done "$OUT_COND" && continue
    if [ "$OUT_COND" = "NONE" ] && [ -f "$RAN_THIS_RUN_DIR/$JOB_ID" ]; then
      continue
    fi

    ready=1
    if [ -n "$IN_COND" ] && [ "$IN_COND" != "NONE" ]; then
      IFS='|' read -ra deps <<< "$IN_COND"
      for d in "${deps[@]}"; do
        job_done "$d" || ready=0
      done
    fi
    [ $ready -eq 0 ] && continue

    # ISOLATION DE PANNE PAR SERVICE (voir en-tete du script) : ce job
    # appartient a un service deja marque en echec plus tot dans CE
    # meme run - jamais tente (pas de suite possible sur une base
    # cassee au sein du MEME service), mais ne bloque JAMAIS les autres
    # services independants qui continuent normalement.
    if [ -n "${SERVICE:-}" ] && [ -f "$FAILED_SERVICES_DIR/$SERVICE" ]; then
      log "$JOB_ID -> SAUTE (service '$SERVICE' deja en echec dans ce run)"
      continue
    fi

    # GEL MANUEL (HELD), ajoute le 2026-08-12 : un job pret (dependances
    # satisfaites) peut avoir ete explicitement gele par un operateur
    # (./bin/hold_job.sh) - distinct d'un blocage sur dependance. On ne le
    # marque pas en echec, on ne le marque pas .ok : on le saute
    # simplement, encore et encore, tant qu'il reste gele. Voir
    # bin/monitoring.sh pour le voir liste separement des jobs EN ATTENTE.
    if job_held "$JOB_ID"; then
      log "$JOB_ID -> GELE (HELD), saute. Liberer avec ./bin/free_job.sh $JOB_ID"
      continue
    fi

    # SUPPRESSION (DELETE), ajoutee le 2026-09-01 - voir lib/commun.sh
    # (job_deleted) et bin/delete_job.sh/bin/undelete_job.sh. Un job supprime
    # est retire du plan courant, jamais tente, jamais liste comme "en
    # attente" par bin/monitoring.sh.
    if job_deleted "$JOB_ID"; then
      log "$JOB_ID -> SUPPRIME (DELETE), saute. Restaurer avec ./bin/undelete_job.sh $JOB_ID"
      continue
    fi

    # CONFIRMATION PREALABLE REQUISE (CONFIRM), ajoutee le 2026-09-01 -
    # voir lib/commun.sh (job_needs_confirm) et bin/confirm_job.sh. Meme
    # traitement que HELD (ni OK ni ECHEC, saute silencieusement tant que
    # non confirme).
    if job_needs_confirm "$JOB_ID"; then
      log "$JOB_ID -> CONFIRMATION REQUISE, saute. Approuver avec ./bin/confirm_job.sh $JOB_ID"
      continue
    fi

    # SAUT VOLONTAIRE PAR CONFIGURATION (SKIP_JOBS), ajoute le 2026-08-14
    # (voir vars.conf et lib/commun.sh, job_in_skip_list) : decide A
    # L'AVANCE, pas une reaction a un incident - le script du job n'est
    # JAMAIS execute, sa condition est marquee satisfaite pour que la
    # suite continue, et c'est journalise de facon INDELEBILE et
    # DISTINCTE (SAUTE_CONFIG, jamais OK/ECHEC/FORCE_OK/MARQUE_FAIT).
    if job_in_skip_list "$JOB_ID"; then
      JOB_TS=$(date +%Y%m%d_%H%M%S_%N)
      mkdir -p "$HISTORY_DIR/$JOB_ID"
      JOB_LOG="$HISTORY_DIR/$JOB_ID/${JOB_TS}.log"
      {
        echo "=== SAUTE VOLONTAIREMENT (SKIP_JOBS dans vars.conf) ==="
        echo "Date/heure : $(date -Iseconds)"
        echo "Ce job n'a PAS ete execute - decide a l'avance dans vars.conf"
        echo "(SKIP_JOBS=\"$SKIP_JOBS\"), typiquement pour un creneau"
        echo "demo/test limite ou ce job est juge non bloquant pour la"
        echo "suite de la chaine. Retirez $JOB_ID de SKIP_JOBS pour qu'il"
        echo "s'execute reellement au prochain lancement."
      } > "$JOB_LOG"
      mark_done "$OUT_COND"
      echo "$(date -Iseconds),$JOB_ID,$JOB_NAME,SAUTE_CONFIG,$JOB_LOG,," >> "$HISTORY_LEDGER"
      log "$JOB_ID -> SAUTE VOLONTAIREMENT (SKIP_JOBS, vars.conf) - $OUT_COND marque sans execution"
      progressed=1
      continue
    fi

    SCRIPT_PATH="$SCRIPT_DIR/jobs/$SCRIPT_FILE"
    if [ ! -f "$SCRIPT_PATH" ]; then
      log "$JOB_ID -> SCRIPT ABSENT ($SCRIPT_FILE), saute (pas encore ecrit). Voir roadmap."
      continue
    fi

    # LANCEMENT PAR VAGUES (voir run_job_async ci-dessus et l'en-tete
    # PARALLELISME REEL) : ce job est pret, il part MAINTENANT en
    # arriere-plan, sans attendre sa fin - d'autres jobs de services
    # differents, prets dans cette MEME passe, partiront juste apres,
    # simultanement. Marquage RAN_THIS_RUN AVANT le lancement (comme
    # avant) : ecrit ici dans le processus PARENT (jamais dans le
    # sous-shell), aucune course possible avec une passe suivante.
    [ "$OUT_COND" = "NONE" ] && touch "$RAN_THIS_RUN_DIR/$JOB_ID"
    run_job_async "$JOB_ID" "$JOB_NAME" "$SCRIPT_FILE" "$DESC" "$OUT_COND" "$SERVICE" &
    RUNNING_COUNT=$((RUNNING_COUNT + 1))
    # Plafond de parallelisme (MAX_PARALLEL_JOBS, vars.conf) : motif
    # bash classique "pool" - des qu'on atteint le plafond, on attend
    # qu'UN SEUL job (n'importe lequel) libere un emplacement avant de
    # continuer a lancer les suivants de cette meme passe.
    if [ "$RUNNING_COUNT" -ge "$MAX_PARALLEL_JOBS" ]; then
      wait -n
      RUNNING_COUNT=$((RUNNING_COUNT - 1))
    fi
    progressed=1
  done < "$JOBS_CSV"
  # Attend TOUS les jobs de CETTE passe (au-dela du plafond deja
  # attendus ci-dessus) avant d'evaluer la passe suivante - une passe
  # ne peut jamais chevaucher la suivante, exactement comme une vague
  # Control-M se termine avant que la suivante soit evaluee.
  wait
  RUNNING_COUNT=0
  [ $progressed -eq 0 ] && break
done

log "=== Fin orchestrateur ==="
log "Etat final (jobs termines) :"
ls "$STATE_DIR" 2>/dev/null | grep '\.ok$' | tee -a "$RUN_LOG"

FAILED_COUNT="$(find "$FAILED_SERVICES_DIR" -type f 2>/dev/null | wc -l)"
if [ "$FAILED_COUNT" -gt 0 ]; then
  log "=== ${FAILED_COUNT} service(s) en echec : $(ls "$FAILED_SERVICES_DIR" 2>/dev/null | tr '\n' ' ') (les autres services independants ont ete tentes jusqu'au bout) ==="
  exit 1
fi
exit 0
