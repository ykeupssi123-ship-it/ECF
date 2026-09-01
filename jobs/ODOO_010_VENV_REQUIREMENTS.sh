#!/bin/bash
# ODOO_010_VENV_REQUIREMENTS - WEF_ODOO_BLD_VENV - Environnement Python
# isole (jamais les paquets Odoo installes dans le Python systeme) +
# dependances reelles du requirements.txt officiel du depot clone
set -uo pipefail
source "$VARS_FILE"

SRC_DIR="${ODOO_HOME}/odoo-src"
VENV_DIR="${ODOO_HOME}/venv"

# CORRIGE le 2026-09-01, 2e passe (echec reel : Odoo 19 exige >= 3.10 en
# dur, voir docs/JOURNAL_TECHNIQUE.md et le correctif jumeau dans
# ODOO_006_PYTHON_BUILD_DEPS.sh qui compile desormais Python 3.11.16
# depuis les sources en "/usr/local/bin/python3.11" via "make
# altinstall"). Chemin ABSOLU utilise ici, jamais le nom nu "python3.11" :
# "sudo -u odoo" applique le secure_path de sudoers, qui n'inclut pas
# forcement /usr/local/bin - jamais suppose, toujours explicite.
PY_BIN="/usr/local/bin/python3.11"
if [ -f "${VENV_DIR}/bin/activate" ]; then
  echo "[ODOO_010] Environnement virtuel deja present, ignore la creation."
else
  echo "[ODOO_010] Creation de l'environnement virtuel Python 3.11..."
  sudo -u "${ODOO_USER}" "$PY_BIN" -m venv "${VENV_DIR}"
fi

echo "[ODOO_010] Installation des dependances (requirements.txt officiel du depot Odoo)..."
sudo -u "${ODOO_USER}" bash -c "source '${VENV_DIR}/bin/activate' && pip install --upgrade pip wheel setuptools && pip install -r '${SRC_DIR}/requirements.txt'"

# CORRIGE le 2026-09-01 : "import odoo" seul ne declenche PAS l'import de
# odoo/cli/command.py (ou vivait la SyntaxError reelle) - la verification
# passait donc a tort meme avec un environnement casse. "import odoo.cli"
# reproduit exactement le premier import fait par odoo-bin en production.
echo "[ODOO_010] Verification reelle : odoo.cli s'importe sans erreur (meme chemin qu'odoo-bin)..."
if ! sudo -u "${ODOO_USER}" bash -c "source '${VENV_DIR}/bin/activate' && cd '${SRC_DIR}' && python3 -c 'import odoo.cli'"; then
  echo "[ODOO_010] ERREUR : odoo.cli ne s'importe pas apres installation des dependances." >&2
  exit 1
fi

echo "[ODOO_010] OK."
exit 0
