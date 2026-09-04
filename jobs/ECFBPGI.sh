#!/bin/bash
# ECFBPGI - ECF_ODOO_BLD_PGINSTALL - Installation de
# PostgreSQL (la base de donnees d'Odoo - fait partie de son ecosysteme
# immediat, jamais suppose deja present sur la machine)
#
# Oracle Linux 8 n'a pas PostgreSQL 16 dans ses depots par defaut
# (AppStream plafonne a des versions plus anciennes) - depot officiel
# PGDG requis, jamais un module DNF partiel qui limiterait la version.
set -uo pipefail
source "$VARS_FILE"

PGV="${PG_VERSION:-16}"

if rpm -q "postgresql${PGV}-server" &>/dev/null; then
  echo "[ODOO_003] postgresql${PGV}-server deja installe, ignore."
  echo "[ODOO_003] OK."
  exit 0
fi

echo "[ODOO_003] Ajout du depot officiel PGDG..."
dnf install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

echo "[ODOO_003] Desactivation du module PostgreSQL par defaut d'Oracle Linux (evite un conflit de version)..."
dnf -qy module disable postgresql || true

echo "[ODOO_003] Installation de PostgreSQL ${PGV}..."
# CORRIGE le 2026-09-01 (echec reel, voir docs/JOURNAL_TECHNIQUE.md) :
# "postgresql${PGV}-devel" retire de cette liste. Ce paquet PGDG (build
# EL8) exige "perl(IPC::Run)" (infrastructure de tests TAP pour
# extensions serveur) qui n'existe dans aucun depot disponible sur cette
# VM, y compris EPEL - verifie reellement. Or ce paquet est redondant :
# ODOO_006_PYTHON_BUILD_DEPS.sh installe deja "postgresql-devel" (le
# paquet natif AppStream, plus leger, sans cette dependance TAP) qui
# fournit a lui seul pg_config + libpq-fe.h necessaires a la compilation
# de psycopg2 - c'est tout ce dont Odoo a reellement besoin, jamais les
# en-tetes de construction d'extensions serveur PostgreSQL 16.
dnf install -y "postgresql${PGV}-server" "postgresql${PGV}-contrib"

if ! rpm -q "postgresql${PGV}-server" &>/dev/null; then
  echo "[ODOO_003] ERREUR : postgresql${PGV}-server introuvable apres installation (rpm -q)." >&2
  exit 1
fi

echo "[ODOO_003] OK."
exit 0
