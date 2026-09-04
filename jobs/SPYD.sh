#!/bin/bash
# SPYD - ECF_ODOO_BLD_PYDEPS - Dependances systeme
# necessaires a la compilation des paquets Python d'Odoo (psycopg2,
# lxml, Pillow, etc. - toutes compilees depuis les sources sur RHEL/OL,
# contrairement a Debian/Ubuntu qui a des roues pre-compilees) + Python
# 3.11 lui-meme (voir correctif 2026-09-01 ci-dessous).
set -uo pipefail
source "$VARS_FILE"

echo "[ODOO_006] Installation des paquets de developpement..."
dnf install -y \
  gcc gcc-c++ make redhat-rpm-config \
  libxml2-devel libxslt-devel \
  libjpeg-turbo-devel zlib-devel freetype-devel \
  openldap-devel libffi-devel \
  openssl-devel bzip2-devel xz-devel readline-devel \
  sqlite-devel ncurses-devel gdbm-devel libuuid-devel

# CORRIGE le 2026-09-01 (2e echec reel, voir docs/JOURNAL_TECHNIQUE.md) :
# "postgresql-devel" installe seul, une fois les depots PGDG ajoutes par
# ODOO_003, redevient ambigu - PGDG14 a PGDG18 fournissent chacun un
# "Provides: postgresql-devel" via leur paquet lourd "postgresqlNN-devel"
# (celui qui exige perl(IPC::Run), absent de tous les depots ici). dnf a
# deja choisi un candidat PGDG au lieu du paquet natif AppStream leger.
# "--disablerepo=pgdg*" force la resolution UNIQUEMENT dans les depots
# non-PGDG, elimine l'ambiguite a la racine plutot que de dependre de
# l'ordre de resolution de dnf.
dnf install -y --disablerepo='pgdg*' postgresql-devel

# CORRIGE le 2026-09-01 (3e echec reel sur ce sujet, voir
# docs/JOURNAL_TECHNIQUE.md) : la 1ere version de ce correctif basculait
# vers le stream dnf "python39" (Python 3.9) en pensant que ca suffirait
# (l'erreur initiale n'etait qu'une SyntaxError sur l'operateur morse,
# apparue avec 3.8). Faux : Odoo 19 verifie sa propre version minimale au
# demarrage (odoo/release.py : MIN_PY_VERSION = (3, 10), MAX_PY_VERSION =
# (3, 14) - lu reellement dans le code source clone, pas suppose) et
# refuse categoriquement de demarrer sous 3.10. Or Oracle Linux 8 ne
# propose AUCUN stream dnf >= 3.10 (verifie : seuls 3.6/3.8/3.9 existent
# comme modules installables ; les paquets "python3.11"/"python3.12"
# listes par "dnf list available" ne sont que des ".src", pas
# installables). Compilation depuis les sources officielles necessaire -
# meme logique que pour Odoo et PostgreSQL (PGDG) dans ce projet : on ne
# suppose jamais qu'un paquet distro suffit, on verifie le vrai besoin et
# on va chercher la source officielle si besoin.
#
# Choix de version : 3.11.16 (derniere version 3.11 reelle publiee sur
# python.org au 2026-09-01, verifiee via python.org/ftp/python/ et via
# curl -sIL sur l'URL exacte ci-dessous -> HTTP 200 confirme). 3.11 choisi
# plutot que 3.12/3.13/3.14 (toutes dans la plage supportee par Odoo 19) :
# version mature, tres large compatibilite avec les roues C (lxml,
# cryptography, Pillow...) du requirements.txt d'Odoo, moins de risque de
# regression que les versions les plus recentes pour une premiere mise en
# service.
#
# "make altinstall" (jamais "make install") : installe en
# /usr/local/bin/python3.11 SANS toucher /usr/bin/python3 ni les liens
# dont dnf/yum et les outils systeme RHEL dependent - meme prudence que le
# choix "postgresql-devel" plutot que "postgresql16-devel" plus haut :
# n'installer que ce qui est reellement necessaire, jamais ecraser un
# outil systeme existant.
#
# "--enable-optimizations" (PGO) volontairement OMIS : gain de
# performance reel mais cout de compilation tres eleve (plusieurs dizaines
# de minutes) sur cette VM a 1 seul vCPU - ecart connu et assume, adapte a
# une demonstration client, a revisiter si un usage de production reel
# est envisage.
PY_VERSION="3.11.16"
PY_BIN="/usr/local/bin/python3.11"

if [ -x "$PY_BIN" ]; then
  echo "[ODOO_006] Python ${PY_VERSION} deja compile et installe (${PY_BIN}), ignore."
else
  echo "[ODOO_006] Compilation de Python ${PY_VERSION} depuis les sources officielles (necessaire : Odoo 19 exige >= 3.10, indisponible en paquet sur Oracle Linux 8)..."
  PY_BUILD_DIR="${WORK_TMP_DIR}/python-build"
  rm -rf "$PY_BUILD_DIR"
  mkdir -p "$PY_BUILD_DIR"
  cd "$PY_BUILD_DIR"

  curl -sfL -o "python-${PY_VERSION}.tgz" "https://www.python.org/ftp/python/${PY_VERSION}/Python-${PY_VERSION}.tgz"
  tar -xzf "python-${PY_VERSION}.tgz"
  cd "Python-${PY_VERSION}"

  ./configure --prefix=/usr/local >/dev/null
  make -j"$(nproc)" >/dev/null
  make altinstall >/dev/null

  cd /
  rm -rf "$PY_BUILD_DIR"
fi

for bin in "$PY_BIN" gcc; do
  command -v "$bin" >/dev/null || { echo "[ODOO_006] ERREUR : $bin introuvable apres installation." >&2; exit 1; }
done

echo "[ODOO_006] OK ($("$PY_BIN" --version))."
exit 0
