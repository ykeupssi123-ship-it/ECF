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

## JOB_ID court (colonne 1 de jobs_table.csv) — distinct de JOB_NAME

Le patron `ECF_<MODULE>_<TIER>_<FONCTION>` ci-dessus concerne **JOB_NAME**
(colonne 2 — le "Memname" recherchable par joker). **JOB_ID** (colonne 1 —
l'identifiant technique unique, celui qu'on tape dans `bin/order_job.sh
<JOB_ID>`) suit une règle séparée.

**Historique du schéma (deux corrections successives le 4 septembre
2026)** : d'abord passé de `ODOO_001_OS_UPDATE`/`MOD_CRM_ACTIVATE`
(trop long, numéro de séquence arbitraire sans signification, fragile
si un job est inséré/supprimé) à un code 4 caractères sans chiffre
(`SOSU`, `CRAC`). Puis, après examen d'une vraie capture d'écran
Control-M de production (job réel `CAMJCSNSIR` : `CAM`=trigramme
filiale SGCAM, `J`=cycle Jour, `C`=classificateur, `SNSIR`=fonction ;
autre famille `CAMJDB3510`/`CAMMDB3510` où le chiffre est un numéro de
traitement reel et le `J`/`M` distingue Jour/Mois), corrigé une
deuxième fois pour coller fidèlement à cette pratique réelle - jamais
inventée.

**Schéma définitif** : `ECF` (trigramme du projet - deviendra
`CLA`/`OCC`/etc. à la phase filiale, exactement comme `CAM` chez
SGCAM) + 1 lettre de type (`B`=Build/construction, `R`=Run/
exploitation, `C`=Contrôle) + code fonction court, **tout collé, sans
tiret ni underscore** (les séparateurs demandent Shift sur clavier
AZERTY - gênent la saisie répétée en exploitation), chiffres autorisés
quand ils portent un sens réel (ex. désambiguïser plusieurs instances
d'un même scénario de démo).

- Jobs Tier 0 (système) : `ECFB` + 3 lettres de fonction (le code
  système historique, sans son `S` initial) - ex. `ECFBOSU` (OS
  Update), `ECFBPGI` (PostGres Install), `ECFRVER` (VERify, type Run).
- Jobs de module (Tier 1) : `ECFB` + 2 lettres de module + 2 lettres de
  fonction (`AC`/`DE`) - ex. `ECFBCRAC`/`ECFBCRDE` (CRM),
  `ECFBVTAC`/`ECFBVTDE` (Vente). Table des codes module : voir
  `jobs_table.csv`, colonne `SERVICE`.
- Jobs d'illustration (démo) : `ECFR` + fonction + chiffre d'instance
  (une société fictive = une instance, jamais son nom dans l'ID -
  reporté à la phase filiale) - ex. `ECFRSOC1`/`ECFRSOC2`/`ECFRSOC3`
  (création de société, 3 instances), `ECFRFAC1`/`ECFRFAC2`/`ECFRFAC3`
  (facture par email, 3 instances).

Position du cycle (`J`=Jour, `M`=Mois...) réservée mais non utilisée
pour l'instant - aucun job réellement récurrent à ce jour dans ECF
(tout est construction ponctuelle ou démonstration à la demande),
jamais inventé sans un vrai besoin a distinguer.

Cette table de correspondance (JOB_ID → intitulé complet) est
disponible en un coup d'oeil via `JOB_NAME` (colonne 2) et `DESC`
(colonne 6) sur la même ligne - jamais besoin de deviner ce qu'un ID
court signifie, `jobs_table.csv` reste la référence unique.

## Raccourcis d'exploitation CLI (`bin/env_exploitation.sh`, ajouté le 4 septembre 2026, corrigé le même jour)

Inspiré d'une pratique réelle (Control-M, SGABS/Société Générale) : au
lieu de mémoriser des chemins complets, l'opérateur utilise des
variables courtes sourcées dans sa session CLI Linux (ex. `$SEC` au
lieu de `/opt/odoo/erp_crm_factory/secrets`). **Corrigé une fois** :
la première version préfixait chaque variable par `ECF` (`$ECFSEC`,
`$ECFHOME`...) - répétition inutile du nom du projet, alors que chez
SGABS le préfixe codait le **sous-système** (`SM2`, `ADI`, `K11`),
jamais l'entreprise elle-même. Schéma définitif, racine courte et
générique (`$OP`, `$SEC`, `$ETA`, `$LOG`, `$HIST`, `$TMP`, `$BAK`,
`$ODOOHOME`) - `$ECFOP` reste tel quel (déjà juste : chaque
sous-dossier porte le vrai code sous-système via `SERVICE`, ex.
`$ECFOP/cr/rcv`). Facultatif, jamais un job de `jobs_table.csv` (une
convention de nommage n'exécute rien) — voir `bin/env_exploitation.sh`,
à sourcer manuellement (`source bin/env_exploitation.sh`) ou via
`~/.bash_profile`. Chaque raccourci reflète une variable déjà définie
dans `vars.conf` (source unique de vérité, jamais dupliquée).

### Anticipation : nommer le destinataire réel (motif SGABS `SND_BNK`)

`SND_BNK` chez SGABS ne voulait pas dire "envoi" tout court - ça voulait
dire "envoi **destiné à l'entité BNK**" (paire directionnelle nommée,
ex. `SWFMX/BNK` ↔ `BNK/SWFMX`, un dossier par sens). `$ECFOP/<module>/snd`
est aujourd'hui générique. Schéma anticipé, jamais construit avant
qu'un vrai destinataire existe (phase filiale) :

```
$ECFOP/<module>/rcv                 # aujourd'hui : reception generique
$ECFOP/<module>/rcv_<source>        # demain : reception nommee (ex. rcv_portail)
$ECFOP/<module>/snd                 # aujourd'hui : envoi generique
$ECFOP/<module>/snd_<destinataire>  # demain : envoi nomme (ex. snd_dgi, snd_client)
```

### `tmp/` (transit) - ajouté le 4 septembre 2026, construit maintenant, pas anticipé

Différent du point précédent : ceci n'attend pas la phase filiale, un
vrai principe d'ingénierie s'applique dès aujourd'hui. Chez SGABS,
`TempM_BNK` était une étape de transit explicite entre
réception/production et archive (`RCV -> SND_BNK -> Move -> TempM_BNK
-> Copy -> ARC_BNK`) - jamais un détail cosmétique : un job qui lit
`snd/` ne doit jamais tomber sur un fichier à moitié écrit par un autre
job encore en train d'écrire. `ECFBOPD.sh` construit désormais 4
sous-dossiers par module : `rcv`, `snd`, `tmp`, `arc`. **Discipline
exigée pour tout futur job d'import/export** : écrire dans `tmp/`,
puis déplacer (`mv`, atomique sur un même système de fichiers) vers
`snd/` - jamais écrire directement la destination finale.

### Validation d'en-tête avant traitement - règle pour les futurs jobs d'import

Autre pratique réelle SGABS mentionnée par l'utilisateur : des jobs qui
lisaient l'en-tête d'un fichier avant de le traiter (routage/validation
selon le type/la structure détectée), jamais un traitement à l'aveugle.
Règle retenue pour tout futur job d'import construit sur `$ECFOP`
(ex. import clients CSV, import employés) : valider que l'en-tête
(colonnes attendues) correspond au format attendu **avant** de traiter
la moindre ligne - échouer bruyamment et tôt si l'en-tête ne
correspond pas, jamais deviner ou tenter un traitement partiel.

### Traçabilité chemin/opération (`PATH_TOUCHED`) - ajouté le 4 septembre 2026

Motivé par une pratique réelle observée sur le CBS Amplitude (SGABS) :
la base du CBS savait répondre "quel chemin Linux exact a été touché
par quelle opération" sans grep les scripts. Côté ECF, `orchestrator.sh`
tenait déjà un registre d'audit (`state/JOBS_HISTORY.csv`,
`HISTORY_LEDGER`) mais sans le chemin touché. Corrigé : la colonne
`PATH_TOUCHED` (7ᵉ colonne du ledger) est alimentée par un contrat
simple et **opt-in** — un job qui lit/écrit sous `$ECFOP` déclare le(s)
chemin(s) exact(s) touché(s) en les écrivant (un par ligne) dans le
fichier désigné par la variable d'environnement `$ECF_JOB_PATHS_FILE`,
exportée par l'orchestrateur (et par `bin/run_now.sh`,
`bin/rerun_job.sh`, `bin/order_job.sh`) avant chaque lancement de job.
Rien n'oblige un job à s'en servir : les 105 jobs actuels n'y écrivent
rien, la colonne reste vide jusqu'aux premiers vrais jobs
d'import/export. Consultable via `./bin/view_history.sh <JOB_ID>`.
Exemple pour un futur job d'import (voir règle de validation d'en-tête
ci-dessus) :

```bash
echo "$ECFOP/vt/rcv/clients_20260904.csv" >> "$ECF_JOB_PATHS_FILE"
```

**Lien direct avec les futurs jobs (pas qu'une convention passive)** :
ces dossiers n'existent QUE pour être lus/écrits par de vrais jobs -
en croisant `docs/MATRICE_MBTI_ODOO.xlsx`, catégorie
"Interface/Intégration", les candidats déjà identifiés pour devenir de
vrais jobs `ECFB<module><FONCTION>` lors de l'éclatement atomique sont :
import clients CSV (Ventes, `$ECFOP/vt/rcv`), export grand livre PDF
(Comptabilité, `$ECFOP/cp/snd`), import employés (RH, `$ECFOP/rh/rcv`).
Chaque nouveau job d'import/export doit lire/écrire dans son
`$ECFOP/<module>/` dédié - jamais un chemin en dur ailleurs.

## Matrice MBTI des opérations Odoo (`docs/MATRICE_MBTI_ODOO.xlsx`, ajoutée le 4 septembre 2026)

480 scénarios de test (30 par type MBTI × 16 types), organisés en 8
catégories inspirées d'une architecture bancaire de référence fournie
par l'utilisateur (Interface, Catalogue, Tiers, Transaction, Workflow,
Rapports, Inter-modules, Cas limites). Chaque scénario combine 4 axes
réels : S/N (procédure littérale vs exploration de cas limites), T/F
(cohérence logique vs impact humain), E/I (collaboratif vs solo), J/P
(jusqu'à clôture vs interruption/reprise). Voir la feuille "Legende" du
classeur pour le détail complet. Contenu ancré dans les opérations
réelles d'Odoo 19 Community, jamais inventé hors contexte.

## Colonne SERVICE (9ᵉ colonne, ajoutée le 4 septembre 2026)

Regroupe chaque job dans sa branche fonctionnelle indépendante — le
même code que le préfixe module du JOB_ID pour un job de module (`CR`
pour CRM), `SYS` pour les jobs Tier 0, ou `ILL1`/`ILL2`/`ILL3` pour les
groupes de jobs d'illustration. `orchestrator.sh` utilise cette
colonne pour l'**isolation de panne par service** : un échec sur un
service n'arrête plus tout l'orchestrateur, seuls les autres jobs du
MÊME service sont sautés - tous les autres services indépendants
continuent d'être tentés jusqu'au bout. Voir l'en-tête de
`orchestrator.sh` pour le diagnostic complet de ce correctif.

### Groupes d'illustration : `ILL1`/`ILL2`/`ILL3`, jamais le nom du client (corrigé le 4 septembre 2026)

Les 13 jobs `ECFR*` d'illustration (SOC/EMP/CRM/CNG/REC/STK/FAC) sont
regroupés en 3 sociétés fictives : `ILL1` = CLIM AUTO, `ILL2` = COUL,
`ILL3` = PAIN & GLACE. Avant cette date, `JOB_NAME`, `SERVICE`,
`IN_COND` et `OUT_COND` portaient le nom du client en clair
(`ECF_CLIMAUTO_RUN_SOCIETE`, `ILL_CLIMAUTO_SOCIETE_OK`...) — repéré
comme une erreur par l'utilisateur : **le câblage d'un job (son
identité, ses conditions) ne doit jamais porter le nom d'un client
réel**, seul le champ `DESC` (texte libre, lu par un humain, jamais
parsé pour le câblage) le peut. Raison concrète : pour ajouter une 4ᵉ
société d'illustration, l'exploitant doit pouvoir dupliquer un fichier
(`ECFRSOC3.sh` → `ECFRSOC4.sh`), changer `DESC` et le contenu du
script, et écrire simplement `ILL4` en `SERVICE`/`OUT_COND` — jamais
inventer ou réécrire une chaîne de conditions en aval. `ECFBOPD.sh`
exclut ces groupes de la construction de `$ECFOP` via le filtre
`$9!~/^ILL/` (les sociétés d'illustration ne sont pas des modules
d'échange de fichiers réels).

## Cycles calendaires (Phase B, démarrée le 4 septembre 2026)

Les jobs Tier 1 vus jusqu'ici (`OUT_COND=NONE`) sont **déclenchés par
fichier** — ils tournent à chaque lancement de l'orchestrateur, sans
notion de calendrier. Un vrai traitement EOD/EOM (Control-M : jobs
`CYC`, séquence linéaire A→B→C se terminant seule, redémarrée par une
« montée au plan » quotidienne) a besoin d'autre chose :

- **`bin/montee_au_plan.sh`** (équivalent New Day/Active Plan
  Control-M) — pour chaque cycle enregistré dans son registre
  `CYCLE_WINDOWS` (ex. `EOD_VENTES_WINDOW_OPEN`), ouvre une fois par
  jour (ou par mois, `MONTHLY`) une condition `*_WINDOW_OPEN`, après
  avoir **archivé** (jamais supprimé silencieusement,
  `state/plan/history/`) le jalon terminal du cycle précédent.
  Idempotent — relancé plusieurs fois le même jour, ne fait rien après
  la première fois. Écrit un instantané daté, `state/plan/<date>.csv`
  — LE plan du jour, consultable.
- Les jobs de la chaîne utilisent des **`OUT_COND` réels** (pas
  `NONE`) — un vrai jalon persistant, remis à zéro uniquement par
  `montee_au_plan.sh` au cycle suivant, jamais par le job lui-même.
- **Aucun changement de schéma `jobs_table.csv`** : le calendrier vit
  entièrement dans `bin/montee_au_plan.sh` (`CYCLE_WINDOWS`), pas dans
  une colonne — 10 points d'analyse positionnelle (`orchestrator.sh` et
  7 scripts `bin/`) auraient dû être mis à jour pour une colonne
  `CYCLE`, juste après la correction d'un bug critique sur ces mêmes
  fichiers (voir plus bas) — risque jugé disproportionné pour le
  bénéfice, contre une solution additive équivalente.
- **Deux minuteurs systemd distincts, jamais fusionnés** (voir
  `setup/installer_service_montee_au_plan.sh` et
  `setup/installer_service_orchestrateur_periodique.sh`) : l'un ouvre
  les fenêtres (00:05, quotidien), l'autre relance `orchestrator.sh`
  toutes les 15 minutes pour que les jobs devenus éligibles s'exécutent
  réellement — une fenêtre ouverte sans relance périodique ne ferait
  jamais tourner sa chaîne.

### Exemple réel construit : cycle EOD Ventes

`ECFCVTRL` (détecte les devis en attente > 5 jours, rapport dans
`$ECFOP/vt/snd`) → `ECFCVTNT` (annule les devis périmés > 30 jours) →
`ECFCVTRP` (rapport de fin de journée : commandes et CA du jour,
`OUT_COND=EOD_VENTES_TERMINE` — le job qui marque la fin du
traitement). Vérifié par un harnais de simulation isolé (jamais
commité) : ouverture, idempotence le même jour, archivage et
réouverture correcte au jour suivant (simulé en antidatant le marqueur
d'ouverture, jamais en trafiquant l'horloge système).

## Tier 1 — jobs métier réels (éclatement atomique, démarré le 4 septembre 2026)

Chaque module suit le même patron, par exemple pour le CRM :

```
ECF_CRM_BLD_INSTALL       - installe l'addon crm
ECF_CRM_BLD_CONFIGTEAMS   - configure les equipes commerciales
ECF_CRM_BLD_CONFIGSTAGES  - configure le pipeline
ECF_CRM_BLD_RIGHTS        - configure les droits d'acces
ECF_CRM_BLD_ACTIVATE      - active le module (declenche par l'operateur, pas automatique)
ECF_CRM_BLD_DEACTIVATE    - desactive le module (reversible)
ECF_CRM_RUN_CREATELEAD    - cree une piste de vente reelle (ECFRCRCL, CONSTRUIT - reference)
ECF_CRM_RUN_CONVERTOPP    - convertit une piste en opportunite
ECF_CRM_RUN_MOVESTAGE     - fait avancer une opportunite dans le pipeline
ECF_CRM_RUN_MARKWON       - marque une opportunite gagnee
ECF_CRM_RUN_MARKLOST      - marque une opportunite perdue (avec motif)
```

### `ECFRCRCL` (`ECF_CRM_RUN_CREATELEAD`) — job de référence du patron Tier 1

Premier job métier réel construit, sert de patron à tous les suivants.
Différences structurelles avec un job Tier 0 (`BLD`) :

- **`OUT_COND=NONE`** : un job métier n'est jamais "fait une fois pour
  toutes" — il tourne à chaque lancement de l'orchestrateur. Nécessite
  le correctif du 4 septembre 2026 dans `lib/commun.sh`
  (`job_done()`/`mark_done()` traitent `NONE` comme "jamais de jalon
  permanent", au lieu de partager un vrai fichier `state/NONE.ok` entre
  tous les jobs `NONE` - bug latent trouvé en construisant CE job,
  jamais déclenché avant car aucun job répétable n'existait). Garde-fou
  complémentaire dans `orchestrator.sh` (`RAN_THIS_RUN`) : un job
  `NONE` ne s'exécute qu'une fois par lancement de l'orchestrateur,
  jamais une fois par passe de la boucle multi-passes (jusqu'à 30x
  sinon).
- **Entrée réelle, jamais de donnée inventée** : lit
  `$OPERATIONS_DIR/cr/rcv/*.csv`, valide l'en-tête exact avant de
  traiter la moindre ligne (règle documentée plus haut), crée les
  pistes via `_odoo_shell_exec`, puis déplace le fichier traité vers
  `arc/` (jamais laissé dans `rcv/`, jamais retraité au lancement
  suivant) et déclare son chemin dans `$ECF_JOB_PATHS_FILE`.
- **Générique, jamais lié à une société fictive** : contrairement aux
  jobs `ILL1`/`ILL2`/`ILL3`, ce job traite n'importe quel CSV respectant
  le contrat d'en-tête, pour n'importe quelle société réelle en base.
- **Validé par la matrice, jamais dupliqué pour elle** : les 30
  scénarios "Transaction"/"Tiers-Clients" de
  `docs/MATRICE_MBTI_ODOO.xlsx` (× 16 profils) sont le plan de test de
  CE job unique — jamais 480 jobs séparés. Convertir la matrice 1:1 en
  jobs produirait 30 copies de "créer une piste" qui ne varient que par
  le ton du commentaire, absurde en exploitation réelle.

### Module CRM — terminé le 4 septembre 2026 (premier module complet)

5 jobs, tous `OUT_COND=NONE`, tous sur `operations/cr/rcv` :

| JOB_ID | En-tête CSV attendu | Action |
|---|---|---|
| `ECFRCRCL` | `name,partner_name,contact_name,phone,expected_revenue` | crée une piste |
| `ECFRCRCO` | `lead_name` | convertit une piste en opportunité |
| `ECFRCRMV` | `opportunity_name,stage` | avance une opportunité dans le pipeline |
| `ECFRCRWO` | `opportunity_name` | marque une opportunité gagnée |
| `ECFRCRLO` | `opportunity_name,lost_reason` | marque une opportunité perdue |

**Bug trouvé et corrigé en les construisant** : `ECFRCRCO` et `ECFRCRWO`
partageaient d'abord tous deux l'en-tête `"name"` — deux jobs
partageant le même dossier `rcv/` ne doivent JAMAIS pouvoir revendiquer
le même fichier (routage par en-tête ambigu = le premier job à
s'exécuter aurait volé le fichier de l'autre, silencieusement). Corrigé
en donnant à chaque job du même dossier un en-tête strictement unique
(`lead_name` vs `opportunity_name`) — **règle à respecter pour tout
futur job Tier 1** : avant d'ajouter un job à un dossier `rcv/` déjà
utilisé par d'autres jobs, vérifier que son en-tête ne collisionne avec
aucun des en-têtes déjà pris par ce dossier.

### Module Ventes — terminé le 4 septembre 2026 (2ᵉ module complet)

3 jobs, tous `OUT_COND=NONE`, tous sur `operations/vt/rcv` :

| JOB_ID | En-tête CSV attendu | Action |
|---|---|---|
| `ECFRVTDV` | `quote_ref,partner_name,product_name,quantity` | crée un devis (plusieurs lignes groupées par `quote_ref`) |
| `ECFRVTCF` | `order_to_confirm` | confirme un devis en commande |
| `ECFRVTIN` | `order_to_invoice` | crée et valide la facture d'une commande confirmée |

`quote_ref`/`order_to_confirm`/`order_to_invoice` référencent tous le
champ standard Odoo `client_order_ref` (référence client) — jamais le
numéro de séquence auto-généré par Odoo (`S00001`...), pour que les 3
jobs puissent retrouver le même devis/commande de façon stable d'un
CSV à l'autre.

**Cas d'indépendance limite, tranché explicitement** : `ECFRVTIN`
(facturation) a besoin, côté Odoo, que le module `account`
(Comptabilité) soit installé. Volontairement **pas** ajouté en
`IN_COND` (ce serait `VT` dépendant de `CP`, rejeté par
`bin/verifier_independance_modules.sh` — exactement le couplage
WEF-style à éviter). À la place, le job vérifie et échoue clairement
à l'exécution (`assert account_mod, ...`) si le préalable métier réel
manque, plutôt qu'une exception Odoo brute — le module Ventes reste
installable indépendamment, seule cette action précise du pipeline
échoue si son besoin fonctionnel réel n'est pas rempli. Règle à
appliquer identiquement pour tout futur job dont une action précise
nécessite un autre module : jamais un `IN_COND` cross-module, toujours
une vérification explicite et un échec clair dans le job lui-même.

### Module Achat — terminé le 4 septembre 2026 (3ᵉ module complet)

3 jobs, tous `OUT_COND=NONE`, tous sur `operations/ah/rcv`, patron
identique à Ventes (référence stable via `partner_ref`, jamais le
numéro de séquence Odoo) :

| JOB_ID | En-tête CSV attendu | Action |
|---|---|---|
| `ECFRAHPO` | `po_ref,partner_name,product_name,quantity` | crée une commande fournisseur |
| `ECFRAHCF` | `po_to_confirm` | confirme une commande fournisseur |
| `ECFRAHRC` | `po_to_receive` | réceptionne les marchandises (valide le bon de réception) |

Même cas d'indépendance limite que `ECFRVTIN` : `ECFRAHRC` a besoin du
module `stock` côté Odoo (la réception génère un `stock.picking`),
volontairement pas ajouté en `IN_COND` — vérifié et échoue clairement
à l'exécution à la place. **`ECFRAHRC` non encore vérifié sur une
vraie instance Odoo 19** (contrairement aux autres jobs de ce module,
qui réutilisent des patrons déjà exécutés en réel dans les jobs
d'illustration) — `button_validate()` sur un bon de réception suppose
une réception complète en une fois ; à tester sur une VM réelle avant
exploitation en production, voir `docs/JOURNAL_TECHNIQUE.md`.

L'équivalent pour les 31 autres modules reste à construire, module par
module, sur ce même patron. Voir `jobs_table.csv` pour la liste
exhaustive à mesure qu'ils sont ajoutés.

### Règle non négociable : les modules business ne dépendent JAMAIS les uns des autres

Rappel explicite (déjà énoncé, jamais garanti que par une vérification
manuelle ponctuelle jusqu'au 4 septembre 2026) : contrairement à
WAZ_ELK_FACTORY (où `orchestrator.sh` fait `exit 1` à la première
erreur, un service non installé bloque tous les suivants),
`orchestrator.sh` d'ECF isole déjà les pannes par `SERVICE`
(`FAILED_SERVICES`, jamais de `exit 1` global — voir son en-tête).
Mais l'isolation de panne ne suffit pas seule : encore faut-il
qu'AUCUN module business ne pose, dans son `IN_COND`, une dépendance
vers un AUTRE module business. **Garanti désormais
structurellement**, pas seulement par discipline manuelle :
`./bin/verifier_independance_modules.sh` — à relancer après CHAQUE
ajout de job Tier 1, exit 0 si tous les modules business restent
indépendants (ne dépendent que de `SYS`/`ODOO_SYSTEME_PRET` ou
d'eux-mêmes), exit 1 avec le détail exact sinon. Deux catégories
volontairement exemptées de cette règle (documenté, jamais une
échappatoire silencieuse) :

- les groupes d'illustration (`ILL1`/`ILL2`/`ILL3`) qui dépendent du
  module business dont ils démontrent l'usage (ex. `ECFREMP1` dépend
  de `RH_ACTIVE`) — c'est le sujet même de la démo, pas un couplage
  artificiel entre deux modules indépendants ;
- `SYS` qui dépend de `RY` (`ECFRCLN` attend la fin du recyclage des
  données avant la vérification finale) — séquencement interne au
  Tier 0 (système), jamais une dépendance entre deux modules business.

Testé en réel (une fausse dépendance injectée temporairement entre
`VT` et `CR`, détectée avec le détail exact, puis le fichier restauré
à l'identique) avant d'être documenté ici.

## Moteur d'exécution : parallélisme réel par vagues (ajouté le 4 septembre 2026)

L'indépendance structurelle ci-dessus ne suffisait pas seule : jusqu'à
cette date, `orchestrator.sh` restait **strictement séquentiel** — un
job lancé en arrière-plan était immédiatement attendu avant de passer
au suivant, même entre modules déjà prouvés indépendants. Corrigé :
chaque passe de la boucle multi-passes lance désormais **tous** les
jobs prêts de cette passe en parallèle (fonction `run_job_async`),
plafonnés par `MAX_PARALLEL_JOBS` (`vars.conf`, 6 par défaut) — motif
bash "pool" (`wait -n` libère un emplacement individuel, jamais le lot
entier). `ECFRVER` (vérification finale) a été déplacé en parallèle
des 34 modules pour la même raison : un job de test/fiabilité ne doit
jamais bloquer la suite.

Conséquence structurelle assumée : un sous-shell en arrière-plan ne
peut pas modifier une variable du processus parent. `FAILED_SERVICES`
et `RAN_THIS_RUN` (ajoutés le matin même comme tableaux associatifs)
sont devenus des répertoires sur disque
(`state/run_tmp/failed_services/`, `state/run_tmp/ran_this_run/`).
Vérifié par un harnais de simulation isolé (jobs `sleep`/`counter`
factices, jamais commité) avant d'être considéré fiable : démarrage
simultané prouvé, libération d'UN SEUL emplacement (pas du lot entier)
prouvée avec des durées volontairement asymétriques, isolation de
panne par service toujours vraie, job `OUT_COND=NONE` toujours exécuté
une seule fois par lancement malgré les 30 passes possibles. Voir
`docs/JOURNAL_TECHNIQUE.md` pour le détail complet et ce qui reste à
confirmer sur une vraie VM Odoo (comportement sous charge réelle,
jamais testé depuis cet environnement).
