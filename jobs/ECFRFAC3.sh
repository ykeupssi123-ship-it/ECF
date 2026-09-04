#!/bin/bash
# ECFRFAC3 - ECF_ILL3_RUN_FACTUREMAIL -
# Illustration de bout en bout : facture reelle PAIN & GLACE (commande
# grossiste d'un hotel), validee et envoyee REELLEMENT par email -
# demontre au comptable ce qu'Odoo remplace de son suivi Excel.
#
# IN_COND=ODOO_MAIL_SERVER_REAL_OK|COMPTA_ACTIVE|ILL3_STOCK_OK
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL3_FACTURE_MAIL] Creation et envoi reel d'une facture PAIN & GLACE..."
OUT="$(_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'PAIN & GLACE')], limit=1)
assert company, 'societe PAIN & GLACE introuvable'

env['account.chart.template'].with_company(company).try_loading('generic_coa', company, install_demo=False)

Partner = env['res.partner']
client = Partner.search([('name', '=', 'ANKRR - Demonstration facture PAIN GLACE')], limit=1)
if not client:
    client = Partner.create({
        'name': 'ANKRR - Demonstration facture PAIN GLACE',
        'email': 'contact@ankrr.fr',
        'phone': '+225 07 90 80 70 60',
        'street': 'Hotel Ivoire, Cocody',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
        'lang': 'fr_FR',
    })
elif client.lang != 'fr_FR':
    client.lang = 'fr_FR'

Move = env['account.move']
invoice = Move.search([('partner_id', '=', client.id), ('move_type', '=', 'out_invoice'), ('state', '=', 'draft'), ('company_id', '=', company.id)], limit=1)
if not invoice:
    invoice = Move.create({
        'move_type': 'out_invoice',
        'partner_id': client.id,
        'company_id': company.id,
        'invoice_line_ids': [
            (0, 0, {'name': 'Baguette traditionnelle - livraison quotidienne (x100)', 'quantity': 100, 'price_unit': 300}),
            (0, 0, {'name': 'Croissant beurre - petit-dejeuner (x50)', 'quantity': 50, 'price_unit': 500}),
            (0, 0, {'name': 'Glace vanille bac 5L (x3)', 'quantity': 3, 'price_unit': 12000}),
        ],
    })
    invoice.action_post()
elif invoice.state == 'draft':
    invoice.action_post()

print('RESULTAT: facture', invoice.name or invoice.id, 'total', invoice.amount_total, 'etat', invoice.state)

# CORRIGE le 2026-09-02 (voir ILL1_FACTURE_MAIL.sh pour le
# detail complet) : piece jointe PDF reellement attachee + langue
# francaise.
template = env.ref('account.email_template_edi_invoice', raise_if_not_found=False)
assert template, 'modele email facture introuvable'
report = env.ref('account.account_invoices')
if report not in template.report_template_ids:
    template.report_template_ids = [(4, report.id)]
template.with_context(lang='fr_FR').send_mail(invoice.id, force_send=True, email_values={'email_to': 'contact@ankrr.fr'})
print('RESULTAT: email envoye pour facture', invoice.id)
env.cr.commit()
")"
echo "$OUT"

if ! echo "$OUT" | grep -q "email envoye pour facture"; then
  echo "[ILL3_FACTURE_MAIL] ERREUR : l'envoi de la facture par email a echoue." >&2
  exit 1
fi

echo "[ILL3_FACTURE_MAIL] OK (facture envoyee reellement a contact@ankrr.fr)."
exit 0
