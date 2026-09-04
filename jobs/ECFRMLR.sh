#!/bin/bash
# ECFRMLR - ECF_SYS_RUN_MAILSERVERREAL - Configure Odoo
# lui-meme (ir.mail_server) pour envoyer ses emails REELS (factures,
# devis, notifications) via le relais OVH contact@ankrr.fr - jusqu'ici
# seul le test curl autonome (ODOO_SMTP_TEST) utilisait ce relais ;
# Odoo lui-meme restait sur Postfix local (ODOO_016_SMTP_RELAY.sh,
# catchall, jamais livre reellement a l'exterieur).
#
# Necessite secrets/smtp_password.txt (voir ODOO_SMTP_TEST.sh).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SMTP_PW="$(read_or_generate_secret "$PROJECT_ROOT/secrets/smtp_password.txt" non)" || exit 1

echo "[ODOO_MAIL_SERVER_REAL] Configuration du serveur sortant reel dans Odoo..."
_odoo_shell_exec "
Server = env['ir.mail_server']
srv = Server.search([('name', '=', 'OVH Zimbra reel (contact@ankrr.fr)')], limit=1)
vals = {
    'name': 'OVH Zimbra reel (contact@ankrr.fr)',
    'smtp_host': 'smtp.mail.ovh.net',
    'smtp_port': 465,
    'smtp_encryption': 'ssl',
    'smtp_authentication': 'login',
    'smtp_user': 'contact@ankrr.fr',
    'smtp_pass': '${SMTP_PW}',
    'sequence': 1,
    'active': True,
    'from_filter': 'contact@ankrr.fr',
}
if srv:
    srv.write(vals)
else:
    srv = Server.create(vals)
env.cr.commit()
print('RESULTAT: serveur id', srv.id)
"

# CORRIGE le 2026-09-01 (echec REEL decouvert par le client : rejet OVH
# '550 5.7.1 Rejected by policy: From header domain does not align with
# authenticated domain', message reellement revenu dans la boite mail).
# Cause racine identifiee en lisant le code source d'Odoo (jamais
# suppose) : Odoo calcule l'adresse d'expediteur via
# res.company.alias_domain_id.default_from_email (mail_alias_domain.py,
# res_company.py) - AUCUNE societe n'avait ce domaine configure, donc
# Odoo retombait sur son tout dernier repli code en dur : 'OdooBot
# <odoobot@example.com>'. OVH exige que le domaine du 'From' corresponde
# EXACTEMENT au compte authentifie (contact@ankrr.fr) - politique anti-
# usurpation standard, pas une erreur du relais. Correction a la racine
# via mail.alias.domain (mecanisme reel Odoo 17+, remplace les anciens
# parametres systeme mail.default.from/mail.catchall.domain) : applique
# a TOUTES les societes existantes, pas seulement celles de la demo, pour
# qu'aucun futur email sortant ne puisse retomber sur odoobot@example.com.
echo "[ODOO_MAIL_SERVER_REAL] Configuration du domaine d'expedition par defaut (mail.alias.domain)..."
_odoo_shell_exec "
AliasDomain = env['mail.alias.domain']
domain = AliasDomain.search([('name', '=', 'ankrr.fr')], limit=1)
if not domain:
    domain = AliasDomain.create({
        'name': 'ankrr.fr',
        'default_from': 'contact',
        'bounce_alias': 'bounce',
        'catchall_alias': 'catchall',
    })
else:
    domain.default_from = 'contact'
nb = 0
for company in env['res.company'].search([]):
    if company.alias_domain_id != domain:
        company.alias_domain_id = domain.id
        nb += 1
env.cr.commit()
print('RESULTAT: domaine ankrr.fr pret, default_from_email =', domain.default_from_email, '-', nb, 'societe(s) mise(s) a jour')
"

# CORRIGE (meme lecon que odoo_module_activate/deactivate cette nuit,
# voir docs/JOURNAL_TECHNIQUE.md) : "odoo-bin shell" est une REPL - une
# exception Python y est affichee mais jamais propagee comme code de
# sortie du process (qui rend 0 quand meme). On lit le texte REELLEMENT
# imprime, jamais le code de sortie d'une REPL.
echo "[ODOO_MAIL_SERVER_REAL] Test reel de connexion (ir.mail_server.test_smtp_connection)..."
TEST_OUT="$(_odoo_shell_exec "
srv = env['ir.mail_server'].search([('name', '=', 'OVH Zimbra reel (contact@ankrr.fr)')], limit=1)
assert srv, 'serveur introuvable'
try:
    srv.test_smtp_connection()
    print('RESULTAT: connexion SMTP reussie')
except Exception as e:
    print('RESULTAT: ECHEC -', e)
")"
echo "$TEST_OUT"
if ! echo "$TEST_OUT" | grep -q "RESULTAT: connexion SMTP reussie"; then
  echo "[ODOO_MAIL_SERVER_REAL] ERREUR : le test de connexion SMTP a echoue." >&2
  exit 1
fi

echo "[ODOO_MAIL_SERVER_REAL] OK (Odoo peut desormais envoyer de vrais emails via contact@ankrr.fr)."
exit 0
