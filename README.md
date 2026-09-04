# ERP_CRM_FACTORY

Usine d'installation, d'exploitation et de démonstration d'un ERP/CRM réel
(Odoo 19 Community, LGPL) — même moteur d'orchestration bash que
[WAZ_ELK_FACTORY](https://github.com/ykeupssi123-ship-it) (Control-M-like :
`jobs_table.csv` = table de jobs, `IN_COND`/`OUT_COND` = dépendances),
réutilisé tel quel et jamais réécrit pour ce projet — projet volontairement
**autonome** (aucune dépendance fonctionnelle envers WAZ_ELK_FACTORY).

## Démarrage rapide

```bash
cd ~
git clone https://github.com/ykeupssi123-ship-it/ECF.git erp_crm_factory
cd erp_crm_factory
# ajuster vars.conf (IP cible, versions) pour votre VM avant de lancer
./orchestrator.sh
```

Destination toujours identique : `~/erp_crm_factory` (le `cd ~` initial est
volontaire — jamais un chemin qui dépend du répertoire où on se trouvait
avant de lancer la commande, même principe que
`PROCEDURE_CONNEXION_GITHUB.pdf` côté WAZ_ELK_FACTORY).

L'orchestrateur installe tout Tier 0 (OS → PostgreSQL → Python 3.11
compilé → Odoo 19 → nginx HTTPS → DNS interne → sauvegarde → vérification
finale), puis peut activer/désactiver chacun des 34 modules Community
réels du catalogue (Tier 1, voir `docs/CONVENTION_NOMMAGE.md`).

## Opérations d'exploitation (façon Control-M)

Racine minimale — `orchestrator.sh` reste le seul point d'entrée à la
racine. Toutes les actions d'exploitation vivent dans `bin/`, sous le
vrai nom de l'action Control-M correspondante (jamais une paraphrase
française) :

| Action Control-M | Commande |
|---|---|
| Order / Force | `./bin/order_job.sh <JOB_ID> "<raison>"` |
| Hold | `./bin/hold_job.sh <JOB_ID> "<raison>"` |
| Free / Release | `./bin/free_job.sh <JOB_ID>` |
| Rerun | `./bin/rerun_job.sh <JOB_ID> "<raison>"` |
| Set to OK | `./bin/set_to_ok.sh <JOB_ID> "<raison>"` |
| Confirm (pose) | `./bin/require_confirm.sh <JOB_ID> "<raison>"` |
| Confirm (approuve) | `./bin/confirm_job.sh <JOB_ID> "<raison>"` |
| Kill / Force End | `./bin/kill_job.sh <JOB_ID> "<raison>"` |
| Delete | `./bin/delete_job.sh <JOB_ID> "<raison>"` |
| Undelete | `./bin/undelete_job.sh <JOB_ID>` |
| Run Now | `./bin/run_now.sh <JOB_ID>` |
| View History | `./bin/view_history.sh <JOB_ID>` |
| Monitoring | `./bin/monitoring.sh` |
| Tableau de bord web | `python3 bin/tableau_de_bord.py` |

Chaque action exige une raison et retape le JOB_ID en confirmation
(discipline d'audit bancaire, aucune dérogation manuelle silencieuse).

## Documentation

- [`docs/CONVENTION_NOMMAGE.md`](docs/CONVENTION_NOMMAGE.md) — convention
  de nommage des jobs (recherche par pattern, façon Control-M memname).
- [`docs/JOURNAL_TECHNIQUE.md`](docs/JOURNAL_TECHNIQUE.md) — journal
  technique complet : chaque incident réel rencontré, sa cause racine
  vérifiée, la décision prise et pourquoi.
- [`docs/CARTOGRAPHIE_SYSTEMIQUE.md`](docs/CARTOGRAPHIE_SYSTEMIQUE.md)
  — vue d'ensemble architecture (les 3 tiers, le moteur d'exécution,
  parité honnête avec Control-M).
- [`docs/GUIDE_EXPLOITATION_SENIOR.md`](docs/GUIDE_EXPLOITATION_SENIOR.md)
  — guide d'exploitation par scénarios réels (pas une liste de
  commandes).
- [`docs/TABLEAU_DE_BORD_CYCLES_OPERATOIRES.xlsx`](docs/TABLEAU_DE_BORD_CYCLES_OPERATOIRES.xlsx)
  — objectif métier réel et cycle calendaire (EOD/EOM/TFJ) par module,
  le cycle EOD Ventes réel en détail, une simulation à ~50 traitements
  sous le vrai algorithme de parallélisme, et la parité Control-M.

## Principe directeur

Jamais supposé, toujours vérifié. Aucune conformité simulée, aucun
raccourci de démo présenté comme une solution réelle. Voir le journal
technique pour la preuve : chaque correctif de ce projet est né d'un vrai
log lu avant toute hypothèse.
