# ERP_CRM_FACTORY

Usine d'installation, d'exploitation et de démonstration d'un ERP/CRM réel
(Odoo 19 Community, LGPL) — même moteur d'orchestration bash que
[WAZ_ELK_FACTORY](https://github.com/ykeupssi123-ship-it) (Control-M-like :
`jobs_table.csv` = table de jobs, `IN_COND`/`OUT_COND` = dépendances),
réutilisé tel quel et jamais réécrit pour ce projet — projet volontairement
**autonome** (aucune dépendance fonctionnelle envers WAZ_ELK_FACTORY).

## Démarrage rapide

```bash
git clone https://github.com/ykeupssi123-ship-it/ECF.git erp_crm_factory
cd erp_crm_factory
# ajuster vars.conf (IP cible, versions) pour votre VM avant de lancer
./orchestrator.sh
```

L'orchestrateur installe tout Tier 0 (OS → PostgreSQL → Python 3.11
compilé → Odoo 19 → nginx HTTPS → DNS interne → sauvegarde → vérification
finale), puis peut activer/désactiver chacun des 34 modules Community
réels du catalogue (Tier 1, voir `docs/CONVENTION_NOMMAGE.md`).

## Opérations d'exploitation (façon Control-M)

| Action Control-M | Commande de ce projet |
|---|---|
| Rerun | `./rejouer_job.sh <JOB_ID> "<raison>"` |
| Force Run | `./forcer_job.sh <JOB_ID> "<raison>"` |
| Bypass / Set to OK | `./marquer_deja_fait.sh <JOB_ID> "<raison>"` |
| Run Now | `./executer_maintenant.sh <JOB_ID>` |
| Hold | `./geler_job.sh <JOB_ID> "<raison>"` |
| Release | `./liberer_job.sh <JOB_ID>` |
| Kill / Terminate | `./tuer_job.sh <JOB_ID> "<raison>"` |
| Confirm (pose) | `./exiger_confirmation.sh <JOB_ID> "<raison>"` |
| Confirm (approuve) | `./confirmer_job.sh <JOB_ID> "<raison>"` |
| Delete | `./supprimer_job.sh <JOB_ID> "<raison>"` |
| Undelete | `./restaurer_job.sh <JOB_ID>` |
| View Output / Sysout | `./historique_job.sh <JOB_ID> <numero>` |
| View Log / View History | `./historique_job.sh <JOB_ID>` |
| Statut en direct | `./statut_live.sh` |
| Tableau de bord web | `python3 tableau_de_bord.py` |

Chaque action exige une raison et retape le JOB_ID en confirmation
(discipline d'audit bancaire, aucune dérogation manuelle silencieuse).

## Documentation

- [`docs/CONVENTION_NOMMAGE.md`](docs/CONVENTION_NOMMAGE.md) — convention
  de nommage des jobs (recherche par pattern, façon Control-M memname).
- [`docs/JOURNAL_TECHNIQUE.md`](docs/JOURNAL_TECHNIQUE.md) — journal
  technique complet : chaque incident réel rencontré, sa cause racine
  vérifiée, la décision prise et pourquoi.

## Principe directeur

Jamais supposé, toujours vérifié. Aucune conformité simulée, aucun
raccourci de démo présenté comme une solution réelle. Voir le journal
technique pour la preuve : chaque correctif de ce projet est né d'un vrai
log lu avant toute hypothèse.
