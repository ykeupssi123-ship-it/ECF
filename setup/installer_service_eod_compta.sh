#!/bin/bash
# installer_service_eod_compta.sh - AJOUTE LE 2026-09-04 (correction
# de taxonomie - EOD est un marqueur horodate unique, JAMAIS le meme
# minuteur que les cycles TFJ ouverts par ecf-montee-au-plan.timer a
# 00:05). Declenche ECFCCLOCP1 (bascule de la date valeur comptable J->J+1)
# a heure fixe, 23:50 par defaut - AVANT le minuteur TFJ suivant, jamais
# apres (l'ordre reel : fermeture -> EOD -> TFJ de la nuit).
#
# A LANCER UNE SEULE FOIS (racine, root) - idempotent.
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
SERVICE_PATH="/etc/systemd/system/ecf-eod-compta.service"
TIMER_PATH="/etc/systemd/system/ecf-eod-compta.timer"

echo "[installer_service_eod_compta] Installation pour : ${SCRIPT_DIR}/jobs/ECFCCLOCP1.sh"

if [ ! -f "${SCRIPT_DIR}/jobs/ECFCCLOCP1.sh" ]; then
  echo "ERREUR : ${SCRIPT_DIR}/jobs/ECFCCLOCP1.sh introuvable." >&2
  exit 1
fi

cat > "$SERVICE_PATH" << UNITEOF
[Unit]
Description=ERP_CRM_FACTORY - Marqueur EOD Comptabilite (bascule date valeur J->J+1)
After=multi-user.target

[Service]
Type=oneshot
WorkingDirectory=${SCRIPT_DIR}
Environment=VARS_FILE=${SCRIPT_DIR}/vars.conf
ExecStart=${SCRIPT_DIR}/jobs/ECFCCLOCP1.sh
User=root
UNITEOF

cat > "$TIMER_PATH" << TIMEREOF
[Unit]
Description=ERP_CRM_FACTORY - Declenche le marqueur EOD Comptabilite (23:50)

[Timer]
OnCalendar=*-*-* 23:50:00
Persistent=true
Unit=ecf-eod-compta.service

[Install]
WantedBy=timers.target
TIMEREOF

echo "[installer_service_eod_compta] Unites ecrites."
systemctl daemon-reload
systemctl enable --now ecf-eod-compta.timer

if ! systemctl is-active ecf-eod-compta.timer >/dev/null 2>&1; then
  echo "ERREUR : ecf-eod-compta.timer n'est pas actif apres activation." >&2
  systemctl status ecf-eod-compta.timer --no-pager >&2 || true
  exit 1
fi

echo "[installer_service_eod_compta] OK (minuteur actif, declenchement quotidien a 23:50)."
echo "Pour verifier : cat state/valeur_comptable_courante.txt ; cat state/EOD_BASCULES_AUDIT.csv"
exit 0
