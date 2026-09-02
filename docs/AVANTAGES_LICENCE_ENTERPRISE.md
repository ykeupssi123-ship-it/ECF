# Ce que gagne PAIN & GLACE (et tout client similaire) avec la licence Odoo Enterprise

*Rédigé pour un usage concret : le comptable qui tient aujourd'hui son
stock et sa comptabilité sur Excel. Chaque ligne ci-dessous correspond à
un vrai module Enterprise vérifié dans le registre Odoo de ce projet
(`ir_module_module.license='OEEL-1'`, 20 modules réels — voir
`docs/CONVENTION_NOMMAGE.md` et `docs/JOURNAL_TECHNIQUE.md` pour la
méthode de vérification). Aucune promesse commerciale générique : ce que
chaque module fait réellement, et pourquoi ça compte pour ce métier
précis.*

## Ce qu'il a déjà vu tourner dans la démo (Community, gratuit)

- **Stock** (`stock`) : les 6 références de PAIN & GLACE (pain, glace)
  avec quantités réelles, remplaçant directement sa feuille Excel.
- **Comptabilité** (`account`) : facture réelle postée et envoyée par
  email à un client grossiste (hôtel).

## Ce que l'Enterprise ajoute concrètement, module par module

| Module Enterprise | Ce qu'il fait réellement | Pourquoi ça compte pour PAIN & GLACE |
|---|---|---|
| `accountant` (Comptabilité complète) | Rapprochement bancaire automatisé, liasse fiscale, tableaux de bord financiers avancés, suivi de trésorerie | Le comptable ne ressaisit plus les relevés bancaires à la main — l'écart le plus chronophage d'un suivi Excel |
| `stock_barcode` (Codes-barres) | Inventaire au scanner, mouvements de stock en 2 secondes par article | Comptage physique du stock (pain du jour, bacs de glace) sans ressaisie papier→Excel |
| `web_mobile` (Application Android/iPhone) | Application native, utilisable au comptoir ou en réserve, hors ligne | Consultation du stock ou saisie d'une vente depuis le téléphone, sans poste fixe |
| `planning` (Planification) | Plannings du personnel (boulangers, vendeurs glacier), visibles par tous | Remplace le planning papier/Excel affiché en cuisine |
| `sign` (Signature électronique) | Signature de documents à distance (contrats fournisseurs farine/lait, baux) | Plus besoin d'imprimer/scanner pour un fournisseur |
| `appointment` (Prise de rendez-vous en ligne) | Réservation en ligne (gâteaux sur commande, événements glacier) | Un client commande un gâteau d'anniversaire sans appel téléphonique |
| `knowledge` (Base de connaissances) | Recettes, procédures d'hygiène, fiches techniques centralisées | Remplace les recettes sur cahier ou fichiers Word éparpillés |
| `quality_control` (Contrôle qualité) | Points de contrôle qualité tracés (température chambre froide, DLC) | Traçabilité alimentaire réelle, utile en cas de contrôle sanitaire |
| `timesheet_grid` (Feuilles de temps) | Heures réellement travaillées par employé, liées à la paie | Base réelle pour calculer les heures d'un boulanger ou d'un vendeur |
| `marketing_automation` | Campagnes automatiques (ex: relance client qui n'a pas commandé depuis 30 jours) | Fidélisation sans y penser chaque semaine |

## Ce qui reste volontairement HORS de cette liste (non pertinent ici)

`industry_fsm` (interventions terrain), `mrp_plm`/`mrp_workorder`
(production industrielle complexe), `sale_amazon` (connecteur
marketplace), `voip`, `social`, `hr_appraisal`, `sale_subscription`,
`helpdesk`, `web_studio` — réels également, mais sans usage direct pour
une boulangerie-glacier de cette taille. Ne jamais présenter un avantage
qui ne correspond pas à un vrai besoin du client.

## Ce qui n'est PAS un argument commercial ici (honnêteté du projet)

Le Community (gratuit) couvre déjà l'essentiel démontré dans cette
démo : stock, facturation, CRM, RH de base. L'Enterprise se justifie
quand la douleur devient réelle et chiffrable — le temps perdu au
rapprochement bancaire manuel, la ressaisie papier→Excel du stock, ou
la paie calculée à la main. C'est cette douleur précise qu'il faut
faire raconter au client avant de proposer l'abonnement, jamais l'ordre
inverse.
