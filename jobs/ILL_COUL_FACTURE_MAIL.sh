#!/bin/bash
# ILL_COUL_FACTURE_MAIL - ECF_COUL_RUN_FACTUREMAIL - Illustration de bout
# en bout : cree une facture reelle COUL (vente parfumerie), la valide,
# genere le PDF, et l'envoie REELLEMENT par email (contact@ankrr.fr).
#
# IN_COND=ODOO_MAIL_SERVER_REAL_OK|COMPTA_ACTIVE|ILL_COUL_SOCIETE_OK
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_COUL_FACTURE_MAIL] Creation et envoi reel d'une facture COUL..."
OUT="$(_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'COUL')], limit=1)
assert company, 'societe COUL introuvable'

env['account.chart.template'].with_company(company).try_loading('generic_coa', company, install_demo=False)

Partner = env['res.partner']
client = Partner.search([('name', '=', 'ANKRR - Demonstration facture COUL')], limit=1)
if not client:
    client = Partner.create({
        'name': 'ANKRR - Demonstration facture COUL',
        'email': 'contact@ankrr.fr',
        'phone': '+225 07 44 55 66 77',
        'street': 'Cocody Angre',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
    })

Move = env['account.move']
invoice = Move.search([('partner_id', '=', client.id), ('move_type', '=', 'out_invoice'), ('state', '=', 'draft'), ('company_id', '=', company.id)], limit=1)
if not invoice:
    invoice = Move.create({
        'move_type': 'out_invoice',
        'partner_id': client.id,
        'company_id': company.id,
        'invoice_line_ids': [
            (0, 0, {'name': 'Parfum femme edition prestige 100ml (x3)', 'quantity': 3, 'price_unit': 35000}),
            (0, 0, {'name': 'Parfum homme boise intense 100ml (x2)', 'quantity': 2, 'price_unit': 32000}),
            (0, 0, {'name': 'Coffret cadeau personnalise', 'quantity': 1, 'price_unit': 15000}),
        ],
    })
    invoice.action_post()
elif invoice.state == 'draft':
    invoice.action_post()

print('RESULTAT: facture', invoice.name or invoice.id, 'total', invoice.amount_total, 'etat', invoice.state)

template = env.ref('account.email_template_edi_invoice', raise_if_not_found=False)
assert template, 'modele email facture introuvable'
template.send_mail(invoice.id, force_send=True, email_values={'email_to': 'contact@ankrr.fr'})
print('RESULTAT: email envoye pour facture', invoice.id)
env.cr.commit()
")"
echo "$OUT"

if ! echo "$OUT" | grep -q "email envoye pour facture"; then
  echo "[ILL_COUL_FACTURE_MAIL] ERREUR : l'envoi de la facture par email a echoue." >&2
  exit 1
fi

echo "[ILL_COUL_FACTURE_MAIL] OK (facture envoyee reellement a contact@ankrr.fr, verifiez la boite mail)."
exit 0
