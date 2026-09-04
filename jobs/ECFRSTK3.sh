#!/bin/bash
# ECFRSTK3 - ECF_ILL3_RUN_STOCK - Illustration :
# cree les produits reels de PAIN & GLACE (boulangerie + glacier) et
# leur stock initial dans Odoo Inventory - remplace directement le
# suivi Excel du comptable rencontre par le client. IN_COND=STOCK_ACTIVE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL3_STOCK] Creation des produits et du stock initial PAIN & GLACE..."
OUT="$(_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'PAIN & GLACE')], limit=1)
assert company, 'societe PAIN & GLACE introuvable - jouer ILL3_SOCIETE d abord'

# CORRIGE le 2026-09-01, 2e fois (1ere tentative fausse piste :
# create_missing_warehouse() lu dans le code source mais son propre
# docstring dit 'add a warehouse on the FIRST company of the database' -
# ne fait rien des qu'AU MOINS UN entrepot existe deja quelque part dans
# la base, meme pour une AUTRE societe. Cree directement l'entrepot, meme
# schema que ce que cette methode fait en interne pour la 1ere societe.
warehouse = env['stock.warehouse'].search([('company_id', '=', company.id)], limit=1)
if not warehouse:
    code = (company.name[:5] or 'WH').upper().replace(' ', '').replace('&', '')
    warehouse = env['stock.warehouse'].create({
        'name': company.name,
        'code': code,
        'company_id': company.id,
        'partner_id': company.partner_id.id,
    })
assert warehouse, 'aucun entrepot pour PAIN & GLACE'
location = warehouse.lot_stock_id

Product = env['product.product']
produits = [
    {'name': 'Baguette traditionnelle', 'list_price': 300, 'standard_price': 120, 'qty': 150},
    {'name': 'Croissant beurre', 'list_price': 500, 'standard_price': 200, 'qty': 80},
    {'name': 'Pain de mie complet', 'list_price': 1500, 'standard_price': 700, 'qty': 40},
    {'name': 'Glace vanille (bac 5L)', 'list_price': 12000, 'standard_price': 6500, 'qty': 12},
    {'name': 'Glace chocolat (bac 5L)', 'list_price': 12000, 'standard_price': 6500, 'qty': 10},
    {'name': 'Sorbet fruit de la passion (bac 5L)', 'list_price': 13500, 'standard_price': 7200, 'qty': 8},
]
cree = 0
for p in produits:
    prod = Product.search([('name', '=', p['name']), ('company_id', 'in', [company.id, False])], limit=1)
    if not prod:
        prod = Product.create({
            'name': p['name'],
            'type': 'consu',
            'is_storable': True,
            'list_price': p['list_price'],
            'standard_price': p['standard_price'],
            'company_id': company.id,
        })
        cree += 1
    quant = env['stock.quant'].with_context(inventory_mode=True).search([
        ('product_id', '=', prod.id), ('location_id', '=', location.id)
    ], limit=1)
    if not quant:
        quant = env['stock.quant'].with_context(inventory_mode=True).create({
            'product_id': prod.id,
            'location_id': location.id,
            'inventory_quantity': p['qty'],
        })
    else:
        quant.inventory_quantity = p['qty']
    quant.action_apply_inventory()

print('RESULTAT:', cree, 'nouveaux produits, stock initial applique sur', len(produits), 'references')
env.cr.commit()
")"
echo "$OUT"

if ! echo "$OUT" | grep -q "RESULTAT:"; then
  echo "[ILL3_STOCK] ERREUR : creation des produits/stock echouee." >&2
  exit 1
fi

echo "[ILL3_STOCK] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM stock_quant q JOIN product_product pp ON pp.id=q.product_id JOIN product_template pt ON pt.id=pp.product_tmpl_id WHERE pt.company_id=(SELECT id FROM res_company WHERE name='PAIN & GLACE') AND q.quantity > 0;")"
if [ "${NB:-0}" -lt 6 ]; then
  echo "[ILL3_STOCK] ERREUR : seulement ${NB:-0}/6 lignes de stock trouvees en base." >&2
  exit 1
fi

echo "[ILL3_STOCK] OK (${NB} references en stock, verifie en base)."
exit 0
