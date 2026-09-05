# Cartographie systémique — ERP_CRM_FACTORY

*Vue d'ensemble architecture, écrite le 4 septembre 2026. Document de
synthèse — `docs/CONVENTION_NOMMAGE.md` et `docs/JOURNAL_TECHNIQUE.md`
restent les journaux détaillés (chaque décision, chaque bug trouvé et
corrigé, avec sa date et sa preuve). Ici : la structure d'ensemble,
sur une seule page mentale.*

## Résumé en une phrase

Une usine de déploiement Odoo 19 Community, pilotée par un ordonnanceur
bash/CSV inspiré de Control-M (mêmes concepts : jobs, conditions
d'entrée/sortie, isolation de panne par service, vocabulaire
d'exploitation réel), avec un principe directeur non négociable :
**aucun module ni traitement métier ne dépend d'un autre** — vérifié
structurellement, jamais supposé.

## Les 3 tiers

```
Tier 0 - SYSTEME (SERVICE=SYS)
  Installe PostgreSQL, Odoo, Nginx, DNS, sauvegarde, verification.
  20 jobs BLD (construction, une fois pour toutes) + quelques jobs RUN
  (verification, tests SMTP - paralleles, jamais bloquants).
  Point de sortie : ODOO_SYSTEME_PRET (produit par ECFBBCK).

Tier 1 - MODULES (34 SERVICE, ex. CR=CRM, VT=Vente, AH=Achat...)
  Active/desactive chaque module Odoo Community. 88 jobs BLD au total
  (2 par module : ACTIVATE/DEACTIVATE). TOUS partent du MEME point
  (ODOO_SYSTEME_PRET), JAMAIS chaines entre eux - verifie
  automatiquement par ./bin/verifier_independance_modules.sh.

Tier 1 - METIER (jobs RUN reels, repetables, OUT_COND=NONE)
  Les vraies operations ERP/CRM (creer un devis, confirmer une
  commande, marquer une opportunite gagnee...). Generiques, jamais lies
  a un client - lisent un CSV dans $ECFOP/<module>/rcv, ecrivent dans
  arc/. Statut actuel : CRM (5 jobs), Ventes (3 jobs), Achat (3 jobs)
  termines - 31 modules restants, meme patron.

Tier 2 - ILLUSTRATION (SERVICE=ILL1/ILL2/ILL3, 13 jobs RUN)
  Demos avec des donnees realistes (societes fictives CLIM AUTO/COUL/
  PAIN & GLACE) - jamais le nom du client dans le cablage (JOB_NAME/
  SERVICE/conditions), uniquement dans DESC (texte libre).
```

**Total actuel : 116 jobs** (88 build, 28 run).

## Le moteur d'exécution

Depuis le 4 septembre 2026, `orchestrator.sh` fonctionne **par
vagues**, jamais séquentiellement (voir `docs/CONVENTION_NOMMAGE.md`,
section "Moteur d'exécution") :

- Chaque passe de la boucle multi-passes lance **tous** les jobs prêts
  de cette passe en parallèle, plafonnés par `MAX_PARALLEL_JOBS`
  (`vars.conf`).
- **Isolation de panne par service** : un job en échec marque
  uniquement son `SERVICE` — les autres services indépendants
  continuent d'être tentés jusqu'au bout, jamais un `exit 1` global
  (contrairement à WAZ_ELK_FACTORY, le projet frère).
- **Jobs répétables** (`OUT_COND=NONE`) : pas de jalon permanent,
  s'exécutent à chaque lancement de l'orchestrateur (une seule fois
  par lancement, jamais 30 fois malgré les 30 passes possibles).
- **Traçabilité** : chaque exécution laisse un log dédié
  (`state/history/<JOB_ID>/`), une ligne dans le registre d'audit
  (`state/JOBS_HISTORY.csv` — `TIMESTAMP,JOB_ID,JOB_NAME,RESULT,
  LOG_FILE,DURATION_SEC,PATH_TOUCHED`), et le chemin `$ECFOP` exact
  touché s'il y en a un.

## Carte des répertoires

```
/                       orchestrator.sh, vars.conf, jobs_table.csv, README.md (seuls fichiers a la racine)
bin/                    outils d'exploitation quotidienne (vocabulaire Control-M reel)
setup/                  installateurs a lancer une seule fois
jobs/                   un script par JOB_ID
lib/commun.sh           fonctions partagees (job_done, mark_done, isolation de panne...)
docs/                   toute la documentation (ce fichier inclus)
state/                  marqueurs .ok, historique, RUNNING/, run_tmp/ (etat par run)
secrets/                mots de passe (jamais dans Git)
$ECFOP (/opt/odoo/operations)   zone d'echange par module : rcv/snd/tmp/arc
```

## Parité avec Control-M — honnête, pas survendue

| Concept Control-M | État chez ECF |
|---|---|
| Job, Memname, Application/Sub-Application | ✅ `JOB_ID`/`JOB_NAME`/`SERVICE` (`jobs_table.csv`) |
| IN/OUT conditions | ✅ colonnes `IN_COND`/`OUT_COND`, opérateur `\|` (OU) |
| Hold/Free/Rerun/Order/Kill/Confirm/Delete | ✅ `bin/hold_job.sh` et consorts, vocabulaire réel |
| Isolation de panne (un service en échec n'arrête pas les autres) | ✅ `FAILED_SERVICES` (fichiers, `state/run_tmp/`) |
| Exécution parallèle par vague | ✅ depuis le 4 septembre 2026 (`run_job_async`, `MAX_PARALLEL_JOBS`) |
| SYSOUT / historique par exécution | ✅ `state/history/<JOB_ID>/`, `bin/view_history.sh` |
| Calendrier TFJ/EOM/EOW/EOQ/EOY (chaînes auto-déclenchées) | ✅ `bin/montee_au_plan.sh` (`CYCLE_WINDOWS`, 5 cadences) + minuteurs systemd — 1 cycle TFJ réel construit (Ventes), 1 cycle PURGE (mensuel) |
| EOD/CUTOFF (marqueur horodaté, heure fixe) | ✅ `ECFCCLOCP1` (Comptabilité, 23:50) et `ECFCCUT1` (Achat, 15h) — minuteur systemd dédié par marqueur, jamais celui de `montee_au_plan.sh` |
| JOUR/NRT (intraday, garde horaire interne) | ✅ `ECFJALRVT1` (Ventes) — job Tier 1 classique + garde horaire, fréquence réelle via le minuteur périodique de l'orchestrateur |
| REPLAY (rejeu après incident) | ✅ déjà couvert — `bin/rerun_job.sh`/`bin/order_job.sh`, rien à construire |
| PURGE (archivage à froid périodique) | ✅ `ECFCPRG1` — déplace les fichiers `$ECFOP/*/arc/` de plus de 90 jours vers `operations_archive_froide/` |
| SIMULATION (stress test sur miroir) | ❌ absent — nécessite un environnement miroir/sandbox dédié, n'existe pas |
| REALTIME (événementiel, Kafka/webhooks) | ❌ absent, volontairement — architecture événementielle incompatible avec un ordonnanceur batch bash/CSV |
| Montée au plan / New Day (snapshot quotidien) | ✅ `bin/montee_au_plan.sh`, `state/plan/<date>.csv` — vérifié en sandbox (ouverture, idempotence, archivage, réouverture au jour suivant, 4 cadences testées unitairement), jamais sur une vraie VM avec minuteur réel |
| Statistiques d'exécution roulées par jour | ❌ absent — les données brutes existent (`state/JOBS_HISTORY.csv`), rien ne les agrège encore par jour |
| Couleurs d'état en temps réel dans un terminal | ❌ absent — `bin/monitoring.sh` reste textuel |
| Hiérarchie Folder/Application/Sub-Application à 3 niveaux | ❌ absent — un seul niveau (`SERVICE`) |

## Avancement Tier 1 métier (31/34 modules restants)

Terminés : **CRM** (5 jobs), **Ventes** (3 jobs + 1 cycle TFJ de 3 jobs
+ 1 job JOUR), **Achat** (3 jobs + 1 marqueur CUTOFF). **Comptabilité**
a son marqueur EOD (`ECFCCLOCP1`) mais pas encore ses jobs métier Tier 1
propres (création facture, etc.). Patron reproductible (voir
`docs/CONVENTION_NOMMAGE.md`, section Tier 1) : un job générique par
opération métier réelle, jamais un job par scénario de test — la
matrice MBTI (`docs/MATRICE_MBTI_ODOO.xlsx`, 480 scénarios) est le plan
de test de ces jobs, jamais traduite 1:1 en jobs.

## Cycles calendaires (Phase B)

Un module actif ne s'arrête jamais tout seul — il continue de tourner
en tâche de fond selon son propre calendrier (voir
`docs/CONVENTION_NOMMAGE.md`, section "Cycles calendaires", pour la
taxonomie complète JOUR/TFJ/EOD/EOW/EOM/EOQ/EOY/CUTOFF/REPLAY/PURGE/
SIMULATION/REALTIME). Réel construit à ce jour :

- **TFJ** (chaîne de nuit) : Ventes — clôture quotidienne
  (`ECFCRELVT1`→`ECFCVTNT`→`ECFCCLOVT1`).
- **EOD** (marqueur horodaté) : Comptabilité — bascule de date valeur
  (`ECFCCLOCP1`, 23:50, son propre minuteur).
- **CUTOFF** (marqueur horodaté, un flux précis) : Achat — commandes
  fournisseurs (`ECFCCUT1`, 15h).
- **JOUR/NRT** (intraday) : Ventes — suivi des devis envoyés
  (`ECFJALRVT1`, garde horaire 8h-18h).
- **PURGE** (mensuel) : Système — archivage à froid de `$ECFOP/*/arc/`
  (`ECFCPRG1`).

Le mécanisme (`bin/montee_au_plan.sh`, 5 cadences : `DAILY`/`WEEKLY`/
`MONTHLY`/`QUARTERLY`/`YEARLY`, + 2 minuteurs systemd pour TFJ/EOM/EOW/
EOQ/EOY) est générique — ajouter un cycle de ce type à un autre module
ne demande qu'une ligne dans `CYCLE_WINDOWS` et sa propre chaîne de
jobs. EOD/CUTOFF suivent un patron différent (marqueur horodaté, son
propre minuteur dédié à heure fixe — jamais celui de
`montee_au_plan.sh`).
