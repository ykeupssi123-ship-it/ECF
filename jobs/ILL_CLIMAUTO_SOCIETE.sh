#!/bin/bash
# ILL_CLIMAUTO_SOCIETE - ECF_CLIMAUTO_RUN_SOCIETE - Illustration : cree la
# fiche societe reelle "CLIM AUTO" (garage/atelier, Cocody) dans Odoo -
# socle sur lequel s'appuient les jobs RH/CRM/facturation suivants pour
# ce client. Idempotent (recherche par nom avant creation).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_SOCIETE] Creation/verification de la societe CLIM AUTO..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
if not company:
    # CORRIGE le 2026-09-02 (demande reelle du client, ecart connu decouvert
    # trop tard pour les factures deja postees - voir docs/JOURNAL_TECHNIQUE.md) :
    # Odoo REFUSE de changer la devise d'une societe une fois des ecritures
    # comptables postees ('You cannot change the currency of the company
    # since some journal items already exist') - la devise doit donc etre
    # correcte DES LA CREATION, jamais corrigee apres coup. XOF (Franc CFA
    # BCEAO) pour une societe ivoirienne, jamais l'USD par defaut.
    xof = env['res.currency'].search([('name', '=', 'XOF')], limit=1)
    company = env['res.company'].create({
        'name': 'CLIM AUTO',
        'street': 'Boulevard Latrille, Cocody',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
        'currency_id': xof.id if xof else env.company.currency_id.id,
        'phone': '+225 27 22 44 18 90',
        'email': 'contact@climauto.ci',
        'website': 'https://climauto.ci',
    })
    print('RESULTAT: cree', company.id)
else:
    print('RESULTAT: existant', company.id)
env.cr.commit()
"

echo "[ILL_CLIMAUTO_SOCIETE] Verification reelle en base..."
EXISTS="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT 1 FROM res_company WHERE name='CLIM AUTO';")"
if [ "$EXISTS" != "1" ]; then
  echo "[ILL_CLIMAUTO_SOCIETE] ERREUR : societe CLIM AUTO introuvable en base apres creation." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_SOCIETE] OK."
exit 0
