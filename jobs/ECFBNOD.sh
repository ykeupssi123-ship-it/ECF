#!/bin/bash
# ECFBNOD - ECF_ODOO_BLD_NODEJS - Node.js + npm (Odoo en a
# besoin pour compiler les assets web : less, rtlcss - fait partie de
# son ecosysteme immediat, sans quoi l'interface web ne se genere pas
# correctement)
set -uo pipefail
source "$VARS_FILE"

if command -v node >/dev/null 2>&1; then
  echo "[ODOO_008] Node.js deja installe ($(node --version)), ignore."
else
  echo "[ODOO_008] Installation de Node.js (module dnf par defaut d'Oracle Linux 8)..."
  dnf module install -y nodejs:18
fi

echo "[ODOO_008] Installation des paquets npm requis par Odoo (less, rtlcss)..."
npm install -g less rtlcss

for bin in node npm lessc rtlcss; do
  command -v "$bin" >/dev/null || { echo "[ODOO_008] ERREUR : $bin introuvable apres installation." >&2; exit 1; }
done

echo "[ODOO_008] OK."
exit 0
