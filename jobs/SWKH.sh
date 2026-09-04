#!/bin/bash
# SWKH - ECF_ODOO_BLD_WKHTML - wkhtmltopdf (generation
# des PDF de devis/factures/rapports - fait partie de l'ecosysteme
# immediat d'Odoo, jamais dans les depots par defaut d'Oracle Linux)
#
# Version 0.12.6.1 avec Qt patche - la version recommandee par la
# communaute Odoo (les versions sans patch Qt produisent des PDF sans
# en-tetes/pieds de page corrects).
#
# CORRIGE le 2026-09-01 (echec reel, voir docs/JOURNAL_TECHNIQUE.md) :
# le build "centos8" annonce dans ce commentaire n'existe plus dans la
# release GitHub 0.12.6.1-3 (verifie reellement via l'API GitHub - 404
# confirme sur l'ancienne URL). Le mainteneur a renomme la cible EL8 en
# "almalinux8" (meme ABI RHEL8, compatible Oracle Linux 8). "curl -sL"
# sans "-f" ne detectait pas le 404 et ecrivait la page d'erreur HTML de
# GitHub comme si c'etait le RPM ("-sL" seul est silencieux sur les
# erreurs HTTP) - "-f" ajoute pour qu'un futur lien casse le job au lieu
# de produire un fichier invalide silencieusement.
set -uo pipefail
source "$VARS_FILE"

if command -v wkhtmltopdf >/dev/null 2>&1; then
  echo "[ODOO_007] wkhtmltopdf deja installe ($(wkhtmltopdf --version | head -1)), ignore."
  echo "[ODOO_007] OK."
  exit 0
fi

WKHTML_URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox-0.12.6.1-3.almalinux8.x86_64.rpm"
WKHTML_RPM="${WORK_TMP_DIR}/wkhtmltox.rpm"
mkdir -p "$WORK_TMP_DIR"

echo "[ODOO_007] Telechargement de wkhtmltopdf (Qt patche, 0.12.6.1-3)..."
curl -sfL -o "$WKHTML_RPM" "$WKHTML_URL"

echo "[ODOO_007] Installation..."
dnf install -y "$WKHTML_RPM"
rm -f "$WKHTML_RPM"

if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  echo "[ODOO_007] ERREUR : wkhtmltopdf introuvable apres installation." >&2
  exit 1
fi

# CORRIGE le 2026-09-01 (echec reel decouvert en generant une vraie
# facture PDF, voir docs/JOURNAL_TECHNIQUE.md) : le paquet wkhtmltox
# installe ses binaires dans /usr/local/bin, jamais /usr/bin. "root" (et
# donc ce job, et la verification ci-dessus) a bien /usr/local/bin dans
# son PATH et voit la commande - mais Odoo tourne comme l'utilisateur
# systeme "odoo", dont le PATH via sudo (secure_path) EXCLUT
# /usr/local/bin : Odoo levait "Unable to find Wkhtmltopdf on this
# system" malgre un binaire reellement present et fonctionnel. Meme
# categorie de piege que le Python 3.11 compile plus tot ce jour-la
# (ODOO_006/ODOO_010) - desormais verifie systematiquement du point de
# vue du VRAI utilisateur d'execution, jamais seulement root. Lien
# symbolique vers /usr/bin (present dans TOUT PATH raisonnable, quel que
# soit l'utilisateur) plutot que de modifier le PATH d'odoo lui-meme -
# solution la plus simple et la plus robuste.
echo "[ODOO_007] Lien symbolique vers /usr/bin (accessible a tout utilisateur, y compris 'odoo')..."
ln -sf "$(command -v wkhtmltopdf)" /usr/bin/wkhtmltopdf
ln -sf "$(command -v wkhtmltoimage)" /usr/bin/wkhtmltoimage

echo "[ODOO_007] Verification reelle du point de vue de l'utilisateur odoo..."
if ! sudo -u "${ODOO_USER}" wkhtmltopdf --version >/dev/null 2>&1; then
  echo "[ODOO_007] ERREUR : wkhtmltopdf reste introuvable pour l'utilisateur ${ODOO_USER} apres le lien symbolique." >&2
  exit 1
fi

echo "[ODOO_007] OK ($(wkhtmltopdf --version | head -1))."
exit 0
