#!/bin/bash
# SOSU - ECF_ODOO_BLD_OSUPDATE - Terrassement : mise a jour OS
#
# Meme lecon deja tiree sur WAZ_ELK_FACTORY (voir ES_001/geler_job.sh
# apres coup) : ce job ne sert qu'au tout premier deploiement. Une fois
# la machine stable, gelez-le (./geler_job.sh ODOO_001 "raison") pour
# eviter un dnf update declenche par accident sur une machine en service.
set -uo pipefail
source "$VARS_FILE"

echo "[ODOO_001] Mise a jour OS..."
dnf clean all
dnf update -y

# CORRIGE le 2026-09-01 (incident reel, voir docs/JOURNAL_TECHNIQUE.md) :
# - "epel-release" retire. Copie par reflexe depuis WAZ_ELK_FACTORY mais
#   aucun job de ce projet n'en a jamais eu besoin (grep verifie sur tout
#   jobs/) - contraire au principe d'autonomie explicitement demande pour
#   ERP_CRM_FACTORY, et le paquet Fedora generique "epel-release" echoue
#   silencieusement sur Oracle Linux (EPEL y est mirrore via le depot
#   ol8_developer_EPEL, deja present mais desactive, pas via ce RPM).
# - "nc" renomme "nmap-ncat" : c'est le vrai nom du paquet sur OL8/RHEL8,
#   "nc" n'existe pas sous ce nom dans les depots par defaut.
# - Le script n'avait pas "set -e" : un dnf install echouant sur un seul
#   paquet inconnu (ici epel-release et nc) continuait silencieusement et
#   le job se rapportait quand meme "OK" - c'est ce qui a masque
#   l'incident reel. Verification explicite ajoutee ci-dessous, meme
#   discipline que ODOO_002/003/006.
echo "[ODOO_001] Installation des outils de base..."
dnf install -y git wget curl tar gzip which nmap-ncat

for bin in git wget curl tar gzip which nc; do
  command -v "$bin" >/dev/null || { echo "[ODOO_001] ERREUR : $bin introuvable apres installation." >&2; exit 1; }
done

echo "[ODOO_001] OK."
exit 0
