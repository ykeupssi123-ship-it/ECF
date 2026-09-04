#!/bin/bash
# ECFBRES - ECF_ODOO_BLD_MINRESVERIFY - Verification des
# ressources minimales AVANT toute installation
#
# Meme principe qu'ES_B001_RAM_CHECK / INFRA_006_AGENT_RESOURCE_CHECK
# (projet WAZ_ELK_FACTORY) : echec dur et immediat si la machine est
# sous le seuil, jamais un avertissement ignorable. Premier job de la
# chaine (IN_COND=NONE), bloque tout le reste.
set -uo pipefail
source "$VARS_FILE"

MIN_VCPU="${MIN_VCPU_REQUIRED:-1}"
MIN_RAM="${MIN_RAM_GB_REQUIRED:-4}"
MIN_DISK="${MIN_DISK_GB_REQUIRED:-20}"

VCPU=$(nproc)
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
DISK_GB=$(df --output=avail -BG / 2>/dev/null | tail -n1 | tr -dc '0-9')

echo "[ODOO_B001] Detecte : ${VCPU} vCPU, ${RAM_GB} Go RAM, ${DISK_GB} Go disque libre (seuils : ${MIN_VCPU} vCPU / ${MIN_RAM} Go RAM / ${MIN_DISK} Go disque)."

ECHEC=0
[ "$VCPU" -lt "$MIN_VCPU" ] && { echo "[ODOO_B001] ERREUR : vCPU insuffisant." >&2; ECHEC=1; }
[ "$RAM_GB" -lt "$MIN_RAM" ] && { echo "[ODOO_B001] ERREUR : RAM insuffisante (${RAM_GB} Go < ${MIN_RAM} Go)." >&2; ECHEC=1; }
[ "$DISK_GB" -lt "$MIN_DISK" ] && { echo "[ODOO_B001] ERREUR : disque insuffisant." >&2; ECHEC=1; }

if [ "$ECHEC" -eq 1 ]; then
  echo "[ODOO_B001] Machine sous-dimensionnee - installation refusee avant meme de commencer." >&2
  exit 1
fi

echo "[ODOO_B001] OK."
exit 0
