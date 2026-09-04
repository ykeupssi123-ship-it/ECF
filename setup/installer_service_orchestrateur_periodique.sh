#!/bin/bash
# installer_service_orchestrateur_periodique.sh - AJOUTE LE 2026-09-04
# (demande explicite utilisateur - cycles calendaires EOD/EOM).
#
# setup/installer_service_orchestrateur.sh installe ecf-orchestrateur
# comme service oneshot, declenche MANUELLEMENT (systemctl start) -
# adapte a un premier deploiement complet, pas a des jobs cycliques qui
# doivent s'executer TOUT SEULS des que bin/montee_au_plan.sh ouvre
# leur fenetre. Ce script ajoute un minuteur PAR-DESSUS le MEME service
# oneshot (jamais un second service - un seul orchestrator.sh a la
# fois, meme mecanisme de verrou), qui le relance automatiquement toutes
# les 15 minutes. Un cycle EOD ouvert a 00:05 par ecf-montee-au-plan.timer
# est donc reellement execute au plus tard a 00:20, sans intervention
# humaine - c'est CE minuteur qui fait le lien entre "la fenetre est
# ouverte" et "les jobs tournent reellement".
#
# PREREQUIS : setup/installer_service_orchestrateur.sh doit avoir deja
# ete lance (ce script ne fait qu'ajouter le minuteur, jamais recreer
# le service lui-meme).
#
# SECURITE REELLE (comportement systemd standard, pas une protection
# ajoutee ici) : une unite .service (meme oneshot) est un singleton par
# nom - si ecf-orchestrateur.service est encore actif (un premier
# deploiement complet peut prendre plus de 15 minutes) quand le
# minuteur redeclenche, systemd n'en lance JAMAIS une seconde instance
# en parallele - la tentative est simplement un no-op. Jamais deux
# orchestrator.sh concurrents sur la meme machine.
#
# A LANCER UNE SEULE FOIS (racine, root) - idempotent.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERREUR : ce script doit etre lance en root (installation d'un minuteur systemd)." >&2
  exit 1
fi

if ! command -v systemctl &>/dev/null; then
  echo "ERREUR : systemctl introuvable - cette machine ne semble pas utiliser systemd." >&2
  exit 1
fi

if [ ! -f /etc/systemd/system/ecf-orchestrateur.service ]; then
  echo "ERREUR : ecf-orchestrateur.service introuvable - lancez d'abord :" >&2
  echo "  sudo ./setup/installer_service_orchestrateur.sh" >&2
  exit 1
fi

TIMER_PATH="/etc/systemd/system/ecf-orchestrateur.timer"

cat > "$TIMER_PATH" << TIMEREOF
[Unit]
Description=ERP_CRM_FACTORY - Relance periodique de l'orchestrateur (jobs cycliques EOD/EOM)

[Timer]
OnCalendar=*:0/15
Persistent=false
Unit=ecf-orchestrateur.service

[Install]
WantedBy=timers.target
TIMEREOF

echo "[installer_service_orchestrateur_periodique] Unite ecrite dans ${TIMER_PATH}."
systemctl daemon-reload
systemctl enable --now ecf-orchestrateur.timer

if ! systemctl is-active ecf-orchestrateur.timer >/dev/null 2>&1; then
  echo "ERREUR : ecf-orchestrateur.timer n'est pas actif apres activation." >&2
  systemctl status ecf-orchestrateur.timer --no-pager >&2 || true
  exit 1
fi

echo "[installer_service_orchestrateur_periodique] OK (relance toutes les 15 minutes)."
echo ""
echo "ATTENTION : combine a ecf-montee-au-plan.timer, l'orchestrateur tourne"
echo "desormais TOUT SEUL, en continu - les jobs Tier 0/Tier 1 deja termines"
echo "(.ok deja marque) ne sont jamais rejoues, seuls les jobs cycliques"
echo "nouvellement eligibles (fenetre ouverte) et les jobs Tier 1 repetables"
echo "(OUT_COND=NONE) s'executent a chaque passage."
echo "Pour verifier : systemctl list-timers ecf-orchestrateur.timer"
exit 0
