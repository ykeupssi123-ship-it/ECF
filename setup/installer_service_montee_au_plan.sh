#!/bin/bash
# installer_service_montee_au_plan.sh - AJOUTE LE 2026-09-04 (demande
# explicite utilisateur - cycles calendaires EOD/EOM, "montee au plan"
# equivalente au New Day Control-M).
#
# Installe bin/montee_au_plan.sh comme minuteur systemd QUOTIDIEN
# (meme mecanisme que wef-health-guardian.timer, cote WAZ_ELK_FACTORY -
# reutilise a l'identique, jamais reinvente). Horaire par defaut :
# 00:05 chaque jour - TOUJOURS avant que quoi que ce soit d'autre ne
# tourne ce jour-la (les cycles EOD/EOM dependent de conditions que ce
# service, et lui seul, ouvre).
#
# A LANCER UNE SEULE FOIS (racine, root) - idempotent.
#
# IMPORTANT : ce service ouvre les fenetres de cycle (conditions
# WINDOW_OPEN), mais ne fait PAS tourner les jobs de la chaine
# lui-meme - il faut aussi que ./orchestrator.sh soit relance
# periodiquement (voir setup/installer_service_orchestrateur_periodique.sh)
# pour que les jobs devenus eligibles s'executent reellement.
set -uo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERREUR : ce script doit etre lance en root (installation d'un service systemd)." >&2
  exit 1
fi

if ! command -v systemctl &>/dev/null; then
  echo "ERREUR : systemctl introuvable - cette machine ne semble pas utiliser systemd." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_PATH="/etc/systemd/system/ecf-montee-au-plan.service"
TIMER_PATH="/etc/systemd/system/ecf-montee-au-plan.timer"

echo "[installer_service_montee_au_plan] Installation pour : ${SCRIPT_DIR}/bin/montee_au_plan.sh"

if [ ! -x "${SCRIPT_DIR}/bin/montee_au_plan.sh" ]; then
  echo "ERREUR : ${SCRIPT_DIR}/bin/montee_au_plan.sh introuvable ou non executable." >&2
  exit 1
fi

cat > "$SERVICE_PATH" << UNITEOF
[Unit]
Description=ERP_CRM_FACTORY - Montee au plan (New Day, cycles EOD/EOM)
After=multi-user.target

[Service]
Type=oneshot
WorkingDirectory=${SCRIPT_DIR}
ExecStart=${SCRIPT_DIR}/bin/montee_au_plan.sh
User=root
UNITEOF

cat > "$TIMER_PATH" << TIMEREOF
[Unit]
Description=ERP_CRM_FACTORY - Declenche la montee au plan quotidienne (00:05)

[Timer]
OnCalendar=*-*-* 00:05:00
Persistent=true
Unit=ecf-montee-au-plan.service

[Install]
WantedBy=timers.target
TIMEREOF

echo "[installer_service_montee_au_plan] Unites ecrites."
systemctl daemon-reload
systemctl enable --now ecf-montee-au-plan.timer

if ! systemctl is-active ecf-montee-au-plan.timer >/dev/null 2>&1; then
  echo "ERREUR : ecf-montee-au-plan.timer n'est pas actif apres activation." >&2
  systemctl status ecf-montee-au-plan.timer --no-pager >&2 || true
  exit 1
fi

echo "[installer_service_montee_au_plan] OK (minuteur actif, declenchement quotidien a 00:05)."
echo ""
echo "Pour declencher une montee au plan immediate (test, ou rattrapage) :"
echo "  systemctl start ecf-montee-au-plan.service"
echo "Pour verifier :"
echo "  systemctl list-timers ecf-montee-au-plan.timer"
echo "  cat state/plan/\$(date +%Y-%m-%d).csv"
echo "N'oubliez pas setup/installer_service_orchestrateur_periodique.sh pour que"
echo "les jobs de la chaine s'executent une fois la fenetre ouverte."
exit 0
