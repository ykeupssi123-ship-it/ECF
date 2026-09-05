#!/bin/bash
# ECFJDIFCP1 - ECF_COMPTA_JOUR_RELEVEDIFFERE - Job DIFFERE reel (voir
# taxonomie complete, feuille "Taxonomie complete" du tableau de bord).
# IN_COND=COMPTA_ACTIVE, OUT_COND=NONE (continu) - un job DIFFERE est
# un traitement LOURD volontairement decale hors heures de pointe
# (jamais en journee, pour ne pas degrader les performances vecues par
# les utilisateurs) : garde horaire interne sur une PLAGE creuse
# (1h-5h du matin), marqueur UNE FOIS PAR JOUR (contrairement a
# ECFJINTCP1/INTRADAY qui a plusieurs creneaux distincts par jour).
#
# HONNETETE (meme discipline que pour ECFCSTIN1 "Inventaire tournant"
# renomme faute de materiel de terrain) : le catalogue parle de "PDF
# volumineux" - un vrai rendu PDF QWeb par client demanderait de
# confirmer le nom exact du template de releve (account.report_*, non
# verifie sur cet environnement, pas d'instance Odoo reelle
# disponible ici). Construit honnetement le sous-ensemble reel certain :
# un releve texte par client (memes donnees, format different) - a
# remplacer par un vrai _render_qweb_pdf() une fois le bon template
# confirme sur la VM reelle, sans changer ni le declenchement ni le
# critere metier.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

HEURE_DEBUT=1
HEURE_FIN=5
HEURE_COURANTE="$(date +%H | sed 's/^0//')"
AUJOURDHUI="$(date +%Y%m%d)"

if [ "$HEURE_COURANTE" -lt "$HEURE_DEBUT" ] || [ "$HEURE_COURANTE" -ge "$HEURE_FIN" ]; then
  echo "[ECF_COMPTA_JOUR_RELEVEDIFFERE] Hors plage creuse (${HEURE_DEBUT}h-${HEURE_FIN}h, il est ${HEURE_COURANTE}h) - rien a faire (traitement lourd volontairement decale)."
  exit 0
fi

MARQUEUR_DIR="$STATE_DIR/differe_cp"
mkdir -p "$MARQUEUR_DIR"
MARQUEUR="$MARQUEUR_DIR/${AUJOURDHUI}.ok"
if [ -f "$MARQUEUR" ]; then
  echo "[ECF_COMPTA_JOUR_RELEVEDIFFERE] Deja genere aujourd'hui - rien a refaire."
  exit 0
fi

SND_DIR="$OPERATIONS_DIR/cp/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/releves_comptes_${AUJOURDHUI}.txt"

RESULTAT="$(_odoo_shell_exec "
from datetime import date
Partner = env['res.partner']
Move = env['account.move']
debut_mois = date.today().replace(day=1)
partenaires = Partner.search([('customer_rank', '>', 0)])
with open('${RAPPORT}', 'w', encoding='utf-8') as fh:
    total_partenaires = 0
    for p in partenaires:
        ecritures = Move.search([('partner_id', '=', p.id), ('state', '=', 'posted'), ('invoice_date', '>=', debut_mois)])
        if not ecritures:
            continue
        total_partenaires += 1
        fh.write(f'=== Releve de compte - {p.name} ===\n')
        solde = 0.0
        for m in ecritures:
            fh.write(f'{m.invoice_date} | {m.name} | {m.amount_total:.2f}\n')
            solde += m.amount_total
        fh.write(f'Solde du mois : {solde:.2f}\n\n')
print('RESULTAT:', total_partenaires)
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_COMPTA_JOUR_RELEVEDIFFERE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

touch "$MARQUEUR"
echo "[ECF_COMPTA_JOUR_RELEVEDIFFERE] $COUNT releve(s) client genere(s) - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
