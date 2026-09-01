# Convention de nommage des jobs — ERP_CRM_FACTORY

*Même principe que la colonne "Memname" observée sur un vrai écran Control-M (illustration donnée : `cam*snsir` → `CAM` = préfixe pays/entité, `SNSIR` = sous-système/type de fichier — un opérateur retrouve en un instant tous les jobs d'une entité ou d'un sous-système par une simple recherche avec joker). La colonne `JOB_NAME` de `jobs_table.csv` porte ce rôle ici.*

## Le patron

```
ECF_<MODULE>_<TIER>_<FONCTION>
```

| Segment | Rôle | Exemples |
|---|---|---|
| `ECF` | Préfixe fixe du projet (ERP_CRM_FACTORY) — identique sur tous les jobs, comme `CAM` identifie une entité entière | toujours `ECF` |
| `<MODULE>` | Le sous-système — un module Odoo ou `SYS` pour l'installation du système lui-même | `SYS`, `CRM`, `VENTE`, `COMPTA`, `ACHAT`, `STOCK`, `MRP`, `REPAIR`, `FLEET`, `RH`, `POS`, `PROJET`... |
| `<TIER>` | La nature du job | `BLD` (construction/installation), `RUN` (exploitation/démonstration), `CHK` (contrôle/vérification ponctuelle) |
| `<FONCTION>` | Ce que le job fait précisément, en abrégé | `OSUPDATE`, `INSTALL`, `CREATELEAD`, `ACTIVATE`, `DEACTIVATE`... |

## Pourquoi ça marche (la preuve par la recherche)

| Recherche | Ce qu'elle retrouve |
|---|---|
| `ECF_SYS_*` | Tous les jobs d'installation du système (PostgreSQL, Odoo, Nginx...) |
| `ECF_CRM_*` | Tous les jobs du module CRM, installation et démo confondues |
| `ECF_*_BLD_*` | Tous les jobs de construction, tous modules confondus — utile pour un premier déploiement complet |
| `ECF_*_RUN_*` | Tous les jobs d'exploitation/démo, tous modules confondus — utile pour préparer une démonstration client |
| `ECF_REPAIR_RUN_*` | Uniquement les scénarios de démo du module Réparations (SAV/atelier) |

## Application déjà faite

Les 20 jobs Tier 0 (installation du système) suivent déjà ce patron : `ECF_SYS_BLD_<FONCTION>` pour la construction, `ECF_SYS_RUN_SYSTEMVERIFY` pour la vérification finale — corrigé le 1er septembre 2026 (portaient par erreur le préfixe `WEF_`, hérité du copier-coller depuis WAZ_ELK_FACTORY, jamais l'identité de ce projet).

## Application à venir (Tier 1 — modules, Tier 2 — démonstration)

Chaque module suit le même patron, par exemple pour le CRM :

```
ECF_CRM_BLD_INSTALL       - installe l'addon crm
ECF_CRM_BLD_CONFIGTEAMS   - configure les equipes commerciales
ECF_CRM_BLD_CONFIGSTAGES  - configure le pipeline
ECF_CRM_BLD_RIGHTS        - configure les droits d'acces
ECF_CRM_BLD_ACTIVATE      - active le module (declenche par l'operateur, pas automatique)
ECF_CRM_BLD_DEACTIVATE    - desactive le module (reversible)
ECF_CRM_RUN_CREATELEAD    - cree une piste de vente reelle
ECF_CRM_RUN_CONVERTOPP    - convertit une piste en opportunite
ECF_CRM_RUN_MOVESTAGE     - fait avancer une opportunite dans le pipeline
ECF_CRM_RUN_MARKWON       - marque une opportunite gagnee
ECF_CRM_RUN_MARKLOST      - marque une opportunite perdue (avec motif)
```

Voir `jobs_table.csv` pour la liste exhaustive une fois chaque module construit.
