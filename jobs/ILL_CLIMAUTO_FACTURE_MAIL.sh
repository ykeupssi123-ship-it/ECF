#!/bin/bash
# ILL_CLIMAUTO_FACTURE_MAIL - ECF_CLIMAUTO_RUN_FACTUREMAIL - Illustration
# de bout en bout : cree une facture reelle CLIM AUTO (reparation
# climatisation auto), la valide, genere le PDF (wkhtmltopdf), et
# l'envoie REELLEMENT par email via le serveur SMTP reel (contact@ankrr.fr
# comme destinataire, pour verification directe par l'operateur).
#
# IN_COND=ODOO_MAIL_SERVER_REAL_OK|COMPTA_ACTIVE|ILL_CLIMAUTO_SOCIETE_OK
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_FACTURE_MAIL] Creation et envoi reel d'une facture CLIM AUTO..."
OUT="$(_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
assert company, 'societe CLIM AUTO introuvable'

# CORRIGE le 2026-09-01 (echec reel : 'No journal could be found in
# company CLIM AUTO for any of those types: sale') : une societe
# multi-entreprise Odoo n'a AUCUN journal comptable tant qu'un plan
# comptable ne lui a pas ete explicitement charge - creer res.company ne
# suffit jamais. 'generic_coa' est le modele generique reel d'Odoo,
# utilise en repli quand aucune localisation dediee au pays n'existe
# (verifie : pas de l10n_ci pour la Cote d Ivoire dans ce depot source).
env['account.chart.template'].with_company(company).try_loading('generic_coa', company, install_demo=False)

Partner = env['res.partner']
client = Partner.search([('name', '=', 'ANKRR - Demonstration facture CLIM AUTO')], limit=1)
if not client:
    client = Partner.create({
        'name': 'ANKRR - Demonstration facture CLIM AUTO',
        'email': 'contact@ankrr.fr',
        'phone': '+225 07 08 55 21 33',
        'street': 'Zone 4C, Marcory',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
    })

Move = env['account.move']
invoice = Move.search([('partner_id', '=', client.id), ('move_type', '=', 'out_invoice'), ('state', '=', 'draft')], limit=1)
if not invoice:
    invoice = Move.create({
        'move_type': 'out_invoice',
        'partner_id': client.id,
        'company_id': company.id,
        'invoice_line_ids': [
            (0, 0, {'name': 'Revision climatisation - Toyota Hilux (plaque CI-1234-AB)', 'quantity': 1, 'price_unit': 45000}),
            (0, 0, {'name': 'Remplacement compresseur climatisation', 'quantity': 1, 'price_unit': 185000}),
            (0, 0, {'name': 'Recharge gaz refrigerant R134a', 'quantity': 1, 'price_unit': 25000}),
            (0, 0, {'name': 'Main d oeuvre atelier (2h30)', 'quantity': 2.5, 'price_unit': 12000}),
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
  echo "[ILL_CLIMAUTO_FACTURE_MAIL] ERREUR : l'envoi de la facture par email a echoue." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_FACTURE_MAIL] OK (facture envoyee reellement a contact@ankrr.fr, verifiez la boite mail)."
exit 0
