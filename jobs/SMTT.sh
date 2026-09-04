#!/bin/bash
# SMTT - ECF_SYS_RUN_SMTPTEST - Test reel d'envoi SMTP via le
# compte contact@ankrr.fr (relais OVH Zimbra) - independant d'Odoo,
# verifie uniquement que le relais SMTP et les identifiants fonctionnent
# avant de les brancher sur l'envoi reel de factures.
#
# Necessite secrets/smtp_password.txt (mot de passe reel du compte
# Zimbra contact@ankrr.fr) - non fourni par ce projet, a deposer
# manuellement par l'operateur (voir README_SECRETS.txt).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SMTP_PW="$(read_or_generate_secret "$PROJECT_ROOT/secrets/smtp_password.txt" non)" || exit 1

echo "[ODOO_SMTP_TEST] Envoi d'un email de test reel via smtp.mail.ovh.net (contact@ankrr.fr)..."
curl -s --url 'smtps://smtp.mail.ovh.net:465' --ssl-reqd \
  --mail-from 'contact@ankrr.fr' \
  --mail-rcpt 'contact@ankrr.fr' \
  --user "contact@ankrr.fr:${SMTP_PW}" \
  --upload-file - << EOF
From: ERP_CRM_FACTORY <contact@ankrr.fr>
To: contact@ankrr.fr
Subject: Test SMTP reel - ERP_CRM_FACTORY (${FACTORY_HOST_IP})
Date: $(date -R)

Ceci est un test d'envoi SMTP reel depuis la VM ERP_CRM_FACTORY.
Genere par le job ODOO_SMTP_TEST le $(date -Iseconds).
EOF

if [ $? -ne 0 ]; then
  echo "[ODOO_SMTP_TEST] ERREUR : echec de l'envoi SMTP (voir la sortie curl ci-dessus)." >&2
  exit 1
fi

echo "[ODOO_SMTP_TEST] OK (email envoye reellement, verifiez contact@ankrr.fr)."
exit 0
