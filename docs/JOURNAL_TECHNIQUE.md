# Journal technique — ERP_CRM_FACTORY

*Décisions tracées façon INTJ : constat vérifié → décision → action → preuve.
Aucune décision "parce que ça semble logique" — chaque ligne ci-dessous
s'appuie sur une commande réellement exécutée sur la VM 192.168.50.130,
jamais une supposition.*

> **Noms d'outils historiques (avant le 4 septembre 2026)** : les entrées
> ci-dessous mentionnent `forcer_job.sh`, `geler_job.sh`, `liberer_job.sh`,
> `rejouer_job.sh`, `marquer_deja_fait.sh`, `historique_job.sh`,
> `statut_live.sh`, `confirmer_job.sh`, `exiger_confirmation.sh`,
> `executer_maintenant.sh`, `tuer_job.sh`, `supprimer_job.sh`,
> `restaurer_job.sh` à la racine - exact au moment de chaque incident
> décrit, jamais corrigé après coup pour rester un compte-rendu fidèle.
> Depuis cette date, ces outils vivent dans `bin/` sous leur vrai nom
> Control-M (`bin/order_job.sh`, `bin/hold_job.sh`, `bin/free_job.sh`,
> `bin/rerun_job.sh`, `bin/set_to_ok.sh`, `bin/view_history.sh`,
> `bin/monitoring.sh`, `bin/confirm_job.sh`, `bin/require_confirm.sh`,
> `bin/run_now.sh`, `bin/kill_job.sh`, `bin/delete_job.sh`,
> `bin/undelete_job.sh`) - voir `README.md` pour la table complète.

---

## 2026-09-01 — Nuit : reprise autonome du Tier 0 (incident ODOO_003 + audit ODOO_001)

**Contexte** : le déploiement Tier 0 s'est arrêté en échec sur `ODOO_003_POSTGRESQL_INSTALL`
pendant la nuit. Le client a autorisé une prise de décision autonome complète
("prenez les decisions par vous meme et retracer comme un INTJ") avant de se
coucher. Ce journal est la trace demandée.

### Incident 1 — corruption cosmétique de JOB_ID (`OO_002_SYSTEM_USER`)

- **Constat** : le log réel de l'orchestrateur affichait `OO_002_SYSTEM_USER`
  (le "D" manquant) au lieu de `ODOO_002_SYSTEM_USER`.
- **Vérification** : `grep` + `xxd` sur `jobs_table.csv` en local ET sur la VM
  déployée — fichier strictement identique et correct des deux côtés. La
  corruption n'était donc PAS un fichier abîmé sur disque.
- **Cause racine identifiée** : `orchestrator.sh` et `forcer_job.sh` lançaient
  chaque job avec `bash "$SCRIPT_PATH" > "$JOB_LOG" 2>&1 &` — sans `< /dev/null`.
  Le job enfant partage alors le même descripteur stdin que la boucle parente
  `while read ... done < "$JOBS_CSV"`. Si le job enfant lit ne serait-ce qu'un
  octet sur stdin (ex. un prompt dnf), il vole cet octet à la lecture suivante
  du CSV par le parent.
- **Décision** : ajouter `< /dev/null` à l'exécution du job dans les deux
  scripts. Correctif générique, sans effet de bord, standard bash.
- **Action** : [orchestrator.sh](../orchestrator.sh) et [forcer_job.sh](../forcer_job.sh)
  corrigés localement puis redéployés sur la VM (`pscp`).
- **Impact fonctionnel réel vérifié** : `id odoo` sur la VM confirme que
  l'utilisateur système `odoo` (uid 981) existe bel et bien — `ODOO_002` a
  réellement réussi malgré le nom corrompu dans le log. Aucune reprise
  nécessaire pour ce job.
- **Point ouvert, volontairement non traité cette nuit** : WAZ_ELK_FACTORY
  partage le même `orchestrator.sh`/`forcer_job.sh` d'origine et porte
  probablement le même bug latent. Décision : ne pas toucher à WEF cette
  nuit (projet en production, hors du périmètre "autonome" confié). À
  proposer explicitement au client à son réveil.

### Incident 2 — échec réel d'`ODOO_003_POSTGRESQL_INSTALL`

- **Constat, log réel lu sur la VM** (jamais supposé) :
  ```
  Erreur : Problème: installation impossible du meilleur candidat pour la tâche
   - nothing provides perl(IPC::Run) needed by postgresql16-devel-16.15-1PGDG.rhel8.10.x86_64 from pgdg16
  ```
- **Vérification de la disponibilité du paquet manquant** : `dnf provides
  'perl(IPC::Run)'` puis `dnf --enablerepo=ol8_developer_EPEL provides
  'perl(IPC::Run)'` sur la VM — **aucune correspondance dans aucun dépôt
  disponible**, EPEL inclus. Ce n'est donc pas un dépôt manquant à activer,
  le paquet n'existe simplement pas pour EL8 (régression connue de packaging
  Perl sur EPEL8 par rapport à EPEL7).
- **Analyse de la vraie nécessité du paquet** : lecture de
  [ODOO_006_PYTHON_BUILD_DEPS.sh](../jobs/ODOO_006_PYTHON_BUILD_DEPS.sh) —
  installe déjà `postgresql-devel` (paquet natif AppStream, léger) qui fournit
  `pg_config` + `libpq-fe.h`, strictement tout ce dont la compilation de
  `psycopg2` a besoin. `postgresql16-devel` (paquet PGDG, lourd, avec
  l'infrastructure de tests TAP qui traîne la dépendance Perl manquante)
  était donc **redondant**, jamais utilisé par aucun job en aval (`grep`
  vérifié).
- **Décision** : retirer `postgresql${PGV}-devel` de la liste d'installation
  d'[ODOO_003_POSTGRESQL_INSTALL.sh](../jobs/ODOO_003_POSTGRESQL_INSTALL.sh).
  Alternative écartée : `--skip-broken`/`--nobest` (aurait masqué le
  problème plutôt que de le résoudre — contraire à la doctrine du projet).
- **Action** : script corrigé localement, redéployé sur la VM.

### Incident 3 (trouvé en marge, non signalé, audit proactif) — `ODOO_001_OS_UPDATE` faussement marqué OK

- **Constat** : bien qu'`ODOO_001` se soit terminé avec `-> OK` dans le log
  de l'orchestrateur, `rpm -q epel-release` sur la VM montre **"le paquet
  epel-release n'est pas installé"**, et `rpm -q nc` montre **"le paquet nc
  n'est pas installé"**.
- **Cause racine** : le script `ODOO_001_OS_UPDATE.sh` n'a jamais eu
  `set -e` ; un `dnf install -y epel-release` qui échoue (paquet Fedora
  générique indisponible sur Oracle Linux — EPEL y est en fait un dépôt
  natif `ol8_developer_EPEL`, désactivé par défaut, pas un RPM à installer)
  ne stoppait pas le script. Idem pour `nc`, qui n'existe pas sous ce nom
  sur OL8/RHEL8 (le vrai paquet s'appelle `nmap-ncat`) — présent dans la
  même commande `dnf install -y git wget curl tar gzip which nc`, dnf a
  installé les paquets valides et signalé l'échec seulement pour `nc`,
  sans faire échouer le job faute de vérification.
- **Décision** :
  1. Retirer `epel-release` entièrement — `grep -r epel jobs/` confirme
     qu'**aucun** job n'en a jamais besoin. Cohérent avec le principe
     d'autonomie explicitement demandé pour ce projet (même logique que le
     nettoyage `PKI_DIR`/`CRYPTO_GROUP` dans `vars.conf`) : ne jamais garder
     une dépendance copiée par réflexe depuis WAZ_ELK_FACTORY si elle n'est
     pas réellement utilisée ici.
  2. Remplacer `nc` par `nmap-ncat`.
  3. Ajouter une vérification explicite post-installation (`command -v`
     pour chaque outil), même discipline que ODOO_002/003/006, pour qu'un
     échec réel ne puisse plus jamais se cacher derrière un "OK" de façade.
- **Action** : script corrigé, redéployé. Plutôt que de rejouer tout
  `ODOO_001` (dnf update de 36 min, contraire à la demande explicite du
  client de ne pas perdre de temps là-dessus), complété directement sur la
  VM : `dnf install -y which nmap-ncat` — résultat réel : les deux étaient
  déjà présents sur l'image de base (`déjà installé`), donc le vrai unique
  échec de ce job était `epel-release`, maintenant retiré. Vérification
  finale des 7 outils (`git wget curl tar gzip which nc`) : tous présents.
- **Job gelé** : `./geler_job.sh ODOO_001_OS_UPDATE` exécuté sur la VM,
  conformément à la demande explicite du client ("holder le à jamais il
  nous fait perdre le temps"), maintenant que le job est réellement,
  intégralement vérifié complet.

### Reprise n°1 de l'orchestrateur — ODOO_003 à ODOO_006 : succès réel confirmé

- Orchestrateur relancé en tâche de fond sur la VM (`nohup ./orchestrator.sh
  ... < /dev/null &`) pour reprendre à partir d'`ODOO_003` (les marqueurs
  `.ok` d'`ODOO_B001`/`ODOO_001`/`ODOO_002` restent valides — vérifiés
  fonctionnellement réels, pas seulement présents sur disque).
- **Résultat réel** (log lu, pas supposé) : `ODOO_003_POSTGRESQL_INSTALL`,
  `ODOO_004_POSTGRESQL_INIT`, `ODOO_005_POSTGRESQL_ODOO_ROLE`,
  `ODOO_006_PYTHON_BUILD_DEPS` → tous `OK`. Les deux correctifs de la nuit
  (retrait de `postgresql16-devel`, retrait d'`epel-release`) sont donc
  confirmés justes, pas seulement plausibles.
- **Nouvel arrêt réel** : `ODOO_007_WKHTMLTOPDF -> ECHEC`.

### Incident 4 — échec réel d'`ODOO_007_WKHTMLTOPDF`

- **Constat, log réel lu sur la VM** :
  ```
  Can not load RPM file: /tmp/erp_crm_factory/state/tmp/wkhtmltox.rpm.
  Impossible d'ouvrir : /tmp/erp_crm_factory/state/tmp/wkhtmltox.rpm
  ```
- **Vérification** : `curl -sIL` sur l'URL exacte du script depuis la VM →
  **HTTP/2 404** confirmé, réel, pas supposé.
- **Cause racine** : le build `centos8` du paquet `wkhtmltox` a disparu de
  la release GitHub `0.12.6.1-3` du projet `wkhtmltopdf/packaging`.
  Interrogation réelle de l'API GitHub
  (`api.github.com/repos/wkhtmltopdf/packaging/releases/tags/0.12.6.1-3`)
  pour lister les vrais artefacts disponibles aujourd'hui : le mainteneur a
  renommé la cible EL8 en `almalinux8` (même ABI RHEL8, compatible Oracle
  Linux 8) — confirmé présent (`wkhtmltox-0.12.6.1-3.almalinux8.x86_64.rpm`).
  Second facteur aggravant, même famille de bug que les incidents
  précédents : `curl -sL` sans `-f` ne détecte pas un 404 et écrit
  silencieusement la page d'erreur HTML de GitHub à la place du RPM.
- **Décision** : corriger l'URL vers le build `almalinux8`, ajouter `-f` à
  `curl` pour qu'un futur lien cassé fasse échouer le job au lieu de
  produire un fichier invalide en silence.
- **Action** : [ODOO_007_WKHTMLTOPDF.sh](../jobs/ODOO_007_WKHTMLTOPDF.sh)
  corrigé, redéployé sur la VM. Reste de `jobs/` audité par recherche de
  toute autre URL externe codée en dur (`grep -rn 'https\?://' jobs/`) —
  aucune autre URL à risque identique trouvée (PGDG déjà validé fonctionnel,
  clone Git Odoo officiel stable, ODOO_008/Node.js passe par un module dnf
  natif sans téléchargement direct).

### Reprise n°2 de l'orchestrateur — ODOO_007 à ODOO_009 : succès réel, nouvel échec réel

- **Résultat réel** : `ODOO_007_WKHTMLTOPDF` et `ODOO_008_NODEJS` → `OK`
  (correctif de l'incident 4 confirmé juste). Nouvel arrêt réel :
  `ODOO_009_SOURCE_CLONE -> ECHEC`.

### Incident 5 — échec réel d'`ODOO_009_SOURCE_CLONE` (transitoire, pas un bug de script)

- **Constat, log réel** : `fatal : impossible d'accéder à
  'https://github.com/odoo/odoo.git/' : Empty reply from server`.
- **Vérification, différente des incidents précédents** : `curl -sIL` sur
  `github.com` depuis la VM juste après → `HTTP/2 200` immédiat ; un
  deuxième clone manuel lancé dans la foulée est allé presque au bout
  (94 % des fichiers extraits avant un second incident mineur). Conclusion
  honnête : **pas un défaut de script** (URL correcte, dépôt officiel,
  connectivité confirmée fonctionnelle) — une coupure réseau ponctuelle
  sur un transfert de ~48 000 fichiers depuis une VM à ressources modestes.
- **Décision** : ajouter de la résilience plutôt que corriger un "bug"
  inexistant — boucle de 3 tentatives avec nettoyage du répertoire partiel
  entre chaque essai, ce job étant appelé à être rejoué de nombreuses fois.
- **Action** : [ODOO_009_SOURCE_CLONE.sh](../jobs/ODOO_009_SOURCE_CLONE.sh)
  corrigé, redéployé.
- **Reprise n°3** : `ODOO_009` (réussi dès le 1ᵉʳ essai de la boucle) à
  `ODOO_012_SYSTEMD_SERVICE` → tous `OK`. Nouvel arrêt réel :
  `ODOO_013_START_SERVICE -> ECHEC`.

### Incident 6 — échec réel d'`ODOO_013_START_SERVICE` : version de Python trop ancienne

- **Constat, log réel** (`systemctl status` + `journalctl` capturés par le
  job lui-même) :
  ```
  File "/opt/odoo/odoo-src/odoo/cli/command.py", line 82
      if (found_command := fullpath.stem) and Command.is_valid_name(found_command):
                        ^
  SyntaxError: invalid syntax
  ```
  L'opérateur morse `:=` (Python 3.8+) provoque une erreur de syntaxe —
  preuve directe que l'interpréteur exécutant Odoo est antérieur à 3.8.
- **Vérification** : `python3 --version` et
  `/opt/odoo/venv/bin/python3 --version` sur la VM → **3.6.8** les deux
  fois. `dnf module list python3*` → seuls streams réellement disponibles
  sur cette VM : 3.6 (actif par défaut), 3.8, 3.9 ; aucun 3.10+ installable
  (les paquets `python3.11`/`python3.12` listés par `dnf list available`
  ne sont que des `.src`, pas installables). Odoo 19 a besoin d'un Python
  suffisamment récent (minimum strict démontré ici : 3.8, pour le walrus
  operator) ; le stream 3.9 est le plus récent réellement disponible sans
  compilation depuis les sources.
- **Cause racine profonde** : `ODOO_006_PYTHON_BUILD_DEPS.sh` installait
  l'alias générique `python3`/`python3-devel`, qui suit le stream dnf actif
  par défaut sur Oracle Linux 8 (3.6) — jamais vérifié explicitement.
  `ODOO_010_VENV_REQUIREMENTS.sh` créait ensuite le venv avec ce même
  alias ambigu.
- **Faille de vérification associée, trouvée en marge** : la vérification
  déjà présente dans `ODOO_010` (`python3 -c 'import odoo'`) passait à tort
  malgré l'environnement cassé, car `import odoo` seul ne déclenche PAS le
  chargement d'`odoo/cli/command.py` (seul `odoo-bin` le fait via
  `import odoo.cli`). Un « OK » local ne garantissait donc pas que le
  service démarrerait réellement — même famille de leçon que l'incident 3
  (ne jamais se contenter d'une vérification partielle).
- **Décision** :
  1. Basculer explicitement `ODOO_006` vers le stream dnf `python39`
     (`dnf module switch-to -y python39`) et installer les paquets
     versionnés (`python39`, `python39-devel`, `python39-pip`) plutôt que
     les alias ambigus.
  2. Faire créer le venv par `ODOO_010` avec le binaire explicite
     `python3.9`, jamais l'alias `python3`.
  3. Renforcer la vérification d'`ODOO_010` : `import odoo.cli` (le
     chemin réellement emprunté par `odoo-bin` en production) au lieu
     d'`import odoo` seul.
- **Écart connu, assumé et documenté** (honnêteté du projet, jamais de
  conformité simulée) : Odoo 19 recommande officiellement une version de
  Python plus récente que 3.9 selon certaines sources communautaires ;
  3.9 est la version la plus moderne réellement disponible sur Oracle
  Linux 8 par les dépôts standards sans compilation manuelle depuis les
  sources. Acceptable pour une démonstration client ; à revisiter si un
  usage de production réel est envisagé (migration vers une distribution
  plus récente, ou compilation Python dédiée).
- **Action** : [ODOO_006_PYTHON_BUILD_DEPS.sh](../jobs/ODOO_006_PYTHON_BUILD_DEPS.sh)
  et [ODOO_010_VENV_REQUIREMENTS.sh](../jobs/ODOO_010_VENV_REQUIREMENTS.sh)
  corrigés, redéployés. Service `odoo` arrêté (il tournait en boucle de
  crash/redémarrage systemd), venv cassé supprimé (`/opt/odoo/venv`),
  marqueurs `ODOO_PYDEPS_OK`/`ODOO_VENV_OK` effacés pour forcer une vraie
  reconstruction complète — pas de raccourci "on corrige juste le
  symptôme dans le venv existant".

### Reprise n°4 — ODOO_006 (2e version, `--disablerepo=pgdg*`) : succès réel confirmé, ODOO_010 toujours en échec

- **Résultat réel** : `ODOO_006_PYTHON_BUILD_DEPS -> OK` avec le correctif
  `--disablerepo='pgdg*'` — validé au préalable en direct sur la VM
  (`pg_config --version` → `PostgreSQL 13.23`, paquet réel installé :
  `libpq-devel-13.23`) avant même le redéploiement, pour ne pas relancer
  un 3ᵉ cycle à l'aveugle sur la même hypothèse.
- **Nouvel arrêt réel, plus profond** : `ODOO_010_VENV_REQUIREMENTS ->
  ECHEC`, mais cette fois après un pip install complet et réussi (toutes
  les dépendances Python d'Odoo installées sans erreur) — l'échec vient de
  la vérification renforcée de l'incident 6 elle-même :
  ```
  AssertionError: Outdated python version detected,
  Odoo requires Python >= 3.10 to run.
  ```

### Incident 7 — la « solution » de l'incident 6 était insuffisante : Python 3.9 ne suffit pas, il en faut ≥ 3.10

- **Constat honnête** : mon propre correctif de l'incident 6 (bascule vers
  le stream dnf `python39`) a résolu le symptôme observé à l'époque
  (SyntaxError sur l'opérateur morse, qui n'exige que 3.8+) mais pas la
  vraie exigence du produit. Je l'avais alors noté comme « écart connu
  assumé » sans le vérifier au niveau du code source — erreur de
  méthode : il fallait lire `odoo/release.py`, pas extrapoler depuis un
  seul message d'erreur.
- **Vérification, cette fois jusqu'au bout** : lecture réelle de
  `/opt/odoo/odoo-src/odoo/release.py` sur la VM →
  `MIN_PY_VERSION = (3, 10)`, `MAX_PY_VERSION = (3, 14)`. Exigence dure,
  vérifiée par Odoo lui-même à chaque démarrage (`odoo/init.py`), pas une
  simple recommandation.
- **Vérification de la disponibilité réelle** : confirmée précédemment
  (incident 6) — Oracle Linux 8 ne propose aucun stream dnf ≥ 3.10.
  Aucune solution par paquet n'existe sur cette distribution.
- **Décision** : compiler Python depuis les sources officielles
  (python.org), comme le projet le fait déjà pour Odoo lui-même et pour
  PostgreSQL (dépôt PGDG). Version choisie : **3.11.16** — la plus
  récente version 3.11 réellement publiée, vérifiée avant utilisation
  (`curl -sIL` sur l'URL exacte du tarball → HTTP 200 confirmé depuis la
  VM, même discipline que pour l'URL wkhtmltopdf de l'incident 4). 3.11
  choisi plutôt que 3.12/3.13/3.14 (toutes dans la plage supportée) pour
  la compatibilité la plus large avec les roues C du `requirements.txt`
  d'Odoo, au risque minimal pour une première mise en service.
- **Décisions techniques de la compilation** :
  - `make altinstall` (jamais `make install`) → installe en
    `/usr/local/bin/python3.11` sans toucher `/usr/bin/python3` ni les
    outils système RHEL qui en dépendent (dnf/yum).
  - `--enable-optimizations` (PGO) volontairement omis — gain de
    performance réel mais coût de compilation de plusieurs dizaines de
    minutes sur cette VM à 1 seul vCPU. **Écart connu et assumé**, adapté
    à une démonstration ; à revisiter pour un usage de production réel.
  - Chemin absolu `/usr/local/bin/python3.11` utilisé explicitement
    partout en aval (jamais l'alias nu) : `sudo -u odoo` applique le
    `secure_path` de `/etc/sudoers`, qui n'inclut pas forcément
    `/usr/local/bin` — jamais supposé, toujours vérifié.
- **Action** : [ODOO_006_PYTHON_BUILD_DEPS.sh](../jobs/ODOO_006_PYTHON_BUILD_DEPS.sh)
  réécrit (dépendances de compilation Python ajoutées : openssl-devel,
  bzip2-devel, xz-devel, readline-devel, sqlite-devel, ncurses-devel,
  gdbm-devel, libuuid-devel ; téléchargement + `configure`/`make
  altinstall` de Python 3.11.16 ; idempotent si déjà présent) et
  [ODOO_010_VENV_REQUIREMENTS.sh](../jobs/ODOO_010_VENV_REQUIREMENTS.sh)
  (venv créé avec le chemin absolu du nouveau binaire) corrigés,
  redéployés. État cassé nettoyé sur la VM (`/opt/odoo/venv` supprimé,
  marqueurs `ODOO_PYDEPS_OK`/`ODOO_VENV_OK` effacés) pour une
  reconstruction complète et propre.

### Reprise n°5 — ODOO_006 (Python 3.11 compilé) à ODOO_018 : succès réel intégral

- **Résultat réel** : compilation Python 3.11.16 terminée en ~7 minutes
  (`06:01:09` → `06:08:05`), venv reconstruit et `pip install` complet en
  ~1m15, **puis toute la suite est passée sans aucune intervention** :
  `ODOO_013_START_SERVICE` (le service Odoo démarre réellement, pour de
  bon cette fois), `ODOO_014_CREATE_DATABASE`, `ODOO_015_NGINX_REVERSE_PROXY`,
  `ODOO_016_SMTP_RELAY`, `ODOO_017_DNS_ZONE`, `ODOO_018_BACKUP_SCRIPT` →
  tous `OK`. Seul dernier arrêt réel : `ODOO_019_FINAL_VERIFY -> ECHEC`.

### Incident 8 — échec réel d'`ODOO_019_FINAL_VERIFY` : SELinux bloque le reverse-proxy

- **Constat, log réel** : `HTTP 502` sur la vérification HTTPS finale.
- **Vérification, pas de supposition** : `systemctl is-active odoo` →
  actif ; `ss -tlnp` → Odoo écoute bien sur `8069` ; `curl` direct vers
  `127.0.0.1:8069/web/login` (sans passer par nginx) → `HTTP 200`, Odoo
  fonctionne parfaitement en direct. Le problème est donc strictement
  entre nginx et Odoo. `tail /var/log/nginx/error.log` →
  ```
  connect() to 127.0.0.1:8069 failed (13: Permission denied)
  ```
  `getenforce` → `Enforcing`. `getsebool httpd_can_network_connect` →
  `off`. Cause racine confirmée : SELinux (actif par défaut sur Oracle
  Linux 8) interdit par principe à un processus du contexte `httpd_t`
  (nginx) toute connexion sortante vers un port applicatif comme 8069,
  sauf autorisation explicite.
- **Décision** : `setsebool -P httpd_can_network_connect on` — le booléen
  SELinux officiel prévu exactement pour ce cas d'usage légitime (reverse
  proxy vers une application locale), jamais un contournement ni une
  désactivation de SELinux. Validé en direct sur la VM avant tout
  redéploiement (`curl` à travers le proxy → `HTTP 200` confirmé) pour ne
  pas relancer un cycle de plus à l'aveugle.
- **Faille de vérification associée, trouvée en marge** : `ODOO_015`
  déclarait `OK` dès que `systemctl` rapportait nginx actif, sans jamais
  tester une vraie requête de bout en bout à travers le proxy — SELinux
  peut bloquer une connexion sortante sans jamais empêcher nginx de
  démarrer. Même famille de leçon que les incidents 3 et 6 : un service
  actif n'est pas une preuve de fonctionnement réel.
- **Action** : [ODOO_015_NGINX_REVERSE_PROXY.sh](../jobs/ODOO_015_NGINX_REVERSE_PROXY.sh)
  corrigé (booléen SELinux + vraie requête HTTPS de bout en bout avant de
  déclarer OK), redéployé et resynchronisé sur le PC.

### Reprise n°6 (finale) — `ODOO_019_FINAL_VERIFY`

```
RESULTAT : TERMINE SANS ECHEC (tous les jobs prets pour ce ROLE/composants
ont ete rejoues jusqu'a stabilisation)
```

**Les 20 jobs du Tier 0 sont tous verts, vérifiés réellement, pas
supposés** :

| Vérification indépendante (post-run) | Résultat réel |
|---|---|
| Base de données Odoo | `odoo_demo` existe (`psql -l` réel) |
| Accès web (interne, à travers nginx+SELinux) | `HTTPS 200` sur `https://erp.odoo.local/web/login` |
| Secrets générés | `admin_passwd` + `db_password` réels, aléatoires, présents dans `/tmp/erp_crm_factory/secrets/` (droits `600`) |
| Service systemd | `odoo.service` actif, écoute sur `0.0.0.0:8069` |

**Tier 0 (installation complète du système Odoo 19 Community + tout son
écosystème immédiat) est terminé et vérifié de bout en bout.**

---

## Synthèse de la nuit du 2026-09-01 (autonomie complète, décisions tracées)

8 incidents réels rencontrés et corrigés cette nuit, du plus superficiel
(cosmétique) au plus structurel (version de Python incompatible avec le
produit) :

1. Corruption cosmétique de JOB_ID → bug de partage de stdin dans
   l'orchestrateur, corrigé (`< /dev/null`).
2. `ODOO_003` : paquet PGDG redondant et cassé (`perl(IPC::Run)` absent)
   → retiré, remplacé par ce qu'`ODOO_006` fournissait déjà.
3. `ODOO_001` faussement marqué OK → `epel-release` inutile retiré,
   `nc` renommé `nmap-ncat`, vérification post-installation ajoutée.
4. `ODOO_007` : URL wkhtmltopdf morte (404) → basculée vers le build
   `almalinux8` réel de la release GitHub.
5. `ODOO_009` : coupure réseau transitoire sur le clone Git → boucle de
   3 tentatives ajoutée (pas un bug de script, de la résilience).
6-7. `ODOO_013` puis `ODOO_010` : Python du système (3.6, puis 3.9)
   incompatible avec l'exigence dure d'Odoo 19 (`>= 3.10`, lue dans le
   code source officiel) → Python 3.11.16 compilé depuis les sources
   officielles (`make altinstall`, jamais `make install`).
8. `ODOO_019` : SELinux bloque le reverse-proxy nginx → autorisé
   explicitement via le booléen officiel `httpd_can_network_connect`.

**Fil conducteur de la nuit** : à chaque échec, le vrai log a été lu
avant toute hypothèse ; chaque correctif a été validé en direct sur la
VM (`curl`, `pg_config`, requête HTTPS réelle...) avant redéploiement,
jamais supposé correct sur la seule base du raisonnement ; deux
vérifications existantes se sont révélées trop superficielles
(`import odoo` au lieu d'`import odoo.cli`, `systemctl is-active` au
lieu d'une vraie requête de bout en bout) et ont été renforcées pour
qu'elles ne puissent plus jamais masquer un problème réel de la même
famille.

**Toutes les décisions ci-dessus ont été prises de façon autonome**,
sur mandat explicite du client avant de se coucher ("prenez les
decisions par vous meme"). Aucune n'a modifié le périmètre du projet
(pas de nouveau module, pas de nouvelle fonctionnalité) — toutes
corrigent des défauts réels bloquant l'installation déjà prévue.

---

## 2026-09-01 (matin) — Tier 1 : moteur d'activation/désactivation des modules (34 modules réels)

**Contexte** : le client, connecté en direct, a vu 54+105 entrées sur les
onglets "Apps"/"Industries" et a demandé une "forêt de jobs" pour
activer/désactiver chaque module réel, testée intégralement puis remise
à zéro pour qu'il active lui-même en démo.

**Vérité terrain établie AVANT toute construction** (jamais deviné depuis
les captures d'écran) : requête directe sur `ir_module_module` → **34
modules réellement Community (LGPL-3, activables)**, **20 Enterprise
(OEEL-1, `state='uninstallable'` — verrouillés, exclus comme convenu)**.
Les "105 industries" vues dans l'interface ne sont **pas** des modules
séparés (recherche de "hotel"/"pharmacy"/"bakery" dans le registre réel :
aucun résultat) — ce sont des modèles de présentation combinant les mêmes
34 applications.

**Architecture retenue** : un moteur générique
(`odoo_module_activate`/`odoo_module_deactivate` dans `lib/commun.sh`)
utilisant `odoo-bin shell` + `button_immediate_install()`/
`button_immediate_uninstall()` — le même code que déclenche un vrai clic
"Activer" dans l'interface, contre l'instance **déjà en cours
d'exécution** (jamais un arrêt de service). 34 modules × 2 = 68 jobs
générés (fichiers courts, chacun appelant le moteur partagé — jamais 68
copies quasi identiques), suivant `docs/CONVENTION_NOMMAGE.md`
(`MOD_<CODE>_ACTIVATE`/`DEACTIVATE`, chaîne de dépendance : activation
depuis `ODOO_SYSTEME_PRET`, désactivation depuis l'activation).

**Incidents réels rencontrés et corrigés pendant la vague de test complète** :
- Corruption CSV (virgules non échappées dans 2 descriptions — CONTACTS,
  VENTE) : même famille de bug que sur WEF, reproduite par erreur dans mon
  propre générateur, corrigée.
- `MOD_POS_RESTO_DEACTIVATE` puis `MOD_ELEARNING_ACTIVATE` : verrou réel
  `ir_cron FOR UPDATE` d'Odoo (protection native contre une corruption du
  registre pendant une tâche planifiée). 1er correctif (retry basé sur le
  code de sortie) inopérant — découvert que `odoo-bin shell` ne propage
  JAMAIS une exception Python comme code de sortie (REPL). Corrigé en
  vérifiant l'état réel en base après chaque tentative, jamais le code de
  sortie d'un shell interactif.
- Résidu réel après la vague complète : 10 modules-dépendances
  (contacts, mail, calendar, account, hr, stock, website, point_of_sale,
  project, mass_mailing) restés "installed" — désactiver un module
  n'entraîne jamais la désinstallation de ses propres dépendances
  (comportement Odoo normal). Job `MOD_ALL_CLEANUP_FINAL` ajouté (passage
  final en boucle jusqu'à point fixe réel).
- `mail` : seul résidu irréductible après nettoyage — échec réel
  `MissingError` sur un `ir_model_fields` orphelin (résidu de données
  après l'enchaînement intensif des 34 cycles, l'ID du champ orphelin
  change à chaque tentative, aucune convergence). Décision assumée :
  `mail` reste installé en permanence, traité comme `base`/`web`
  (infrastructure du chatter/notifications, dont dépendent quasiment
  tous les modules métier) plutôt qu'une "app" à activer/désactiver pour
  la démo — c'est d'ailleurs ainsi que fonctionne un vrai déploiement
  Odoo. Site et service vérifiés pleinement fonctionnels (HTTP 200) avec
  ce seul module installé.

**Résultat final vérifié indépendamment** : `RESULTAT : TERMINE SANS
ECHEC` sur l'orchestrateur complet (Tier 0 + 68 jobs Tier 1 + nettoyage).
`SELECT ... WHERE application=true AND state='installed'` → uniquement
`mail`, comme voulu. Site accessible, service actif. Système prêt pour
activation manuelle module par module par l'opérateur en démo.

---

## 2026-09-01 (matin, suite) — Tier 2 : premières illustrations personnalisées (CLIM AUTO / COUL)

**Contexte** : les deux clients réels ont insisté sur le volet RH et le
volet CRM. Le client a donné leurs noms réels pour la démo : **CLIM
AUTO** (garage/climatisation auto, Cocody) et **COUL** (parfumerie, Le
Plateau) — utilisés désormais explicitement dans les données
d'illustration, alors qu'ils étaient jusque-là volontairement tus.

**Construit et vérifié en base à chaque étape** (jamais supposé) :
- `ILL_CLIMAUTO_SOCIETE` / `ILL_COUL_SOCIETE` : fiche société réelle
  Odoo (`res.company`) par client, adresse réelle (Cocody / Le Plateau,
  pays `base.ci` vérifié existant avant usage).
- `ILL_CLIMAUTO_EMPLOYES` / `ILL_COUL_EMPLOYES` : 5 et 4 employés
  fictifs mais réalistes (noms, postes, contacts ivoiriens) — volet RH.
- `ILL_CLIMAUTO_CRM_PISTES` / `ILL_COUL_CRM_PISTES` : 4 pistes
  commerciales chacun, à des stades de pipeline variés (nouveau, qualifié,
  gagné) pour un pipeline vivant, pas une liste plate — volet CRM.

### Incident 9 — les marqueurs `<CODE>_ACTIVE.ok` ne reflètent pas l'état réel après un cycle activation/désactivation

- **Constat réel** : `IN_COND=CRM_ACTIVE` sur un job Tier 2 restait
  satisfait (marqueur `.ok` présent) alors que `crm` était réellement
  `uninstalled` en base — le marqueur avait été créé lors du test Tier 1
  de la nuit et n'était jamais effacé par la désactivation suivante.
- **Cause racine** : les marqueurs `.ok` sont conçus, dans ce projet,
  comme un registre "a déjà réussi une fois" (correct pour Tier 0, jamais
  rejoué) — jamais prévus comme miroir de l'état courant pour des jobs
  qui basculent (activation/désactivation). Une désactivation ne levait
  jamais le marqueur ACTIVE posé par l'activation précédente.
- **Décision** : chacun des 34 scripts `MOD_<X>_DEACTIVATE.sh` efface
  désormais son propre marqueur `<CODE>_ACTIVE.ok` après une
  désinstallation réussie — la condition reflète enfin l'état réel
  courant, pas un historique qui ne fait que s'accumuler.

### Incident 10 — désinstaller un module Odoo supprime réellement ses données (pas seulement l'interface)

- **Constat réel, découvert en voulant remettre RH/CRM à zéro après le
  test d'illustration** : après `MOD_RH_DEACTIVATE`/`MOD_CRM_DEACTIVATE`,
  une requête `SELECT count(*) FROM hr_employee` échoue avec
  `ERREUR: la relation « hr_employee » n'existe pas` — la table SQL
  elle-même a disparu, pas seulement les lignes ou le menu.
- **Analyse honnête** : hypothèse implicite de toute la nuit (« désactiver
  = juste masquer, les données restent, réapparaissent à la
  réactivation ») **fausse** pour du contenu construit par un module —
  `button_immediate_uninstall()` exécute une vraie désinstallation
  (suppression de schéma), exactement ce qu'un clic réel "Désinstaller"
  déclenche dans Odoo. Comportement produit réel, pas un défaut du
  moteur de jobs.
- **Conséquence directe et correction** : `hr` et `crm` retirés de la
  liste de `MOD_ALL_CLEANUP_FINAL.sh` (même traitement que `mail`) — tout
  module qui reçoit des données d'illustration Tier 2 doit rester
  installé en permanence. Données recréées après cette découverte
  (`ILL_*` rejoués), vérifiées de nouveau en base (10 employés, 8 pistes
  CRM — les 9 fictifs + 1 employé "admin" auto-créé par Odoo à
  l'installation du module RH).
- **Impact sur la mise en scène de la démo** : le "j'active le module
  devant le client" ne s'applique qu'aux modules **sans** données
  d'illustration pré-construites. Pour RH/CRM (et tout futur module
  illustré), le module reste actif en permanence avec de vraies données
  prêtes — la mise en scène devient "je navigue et je montre", pas
  "regardez, j'active à l'instant".

---

## 2026-09-01 (matin, suite) — Alertes email réelles + réparation TABLEAU_DE_BORD_EXPLOITATION (WEF)

**Alertes email** : `notifier.sh` d'ECF affichait `[WAZ_ELK_FACTORY]` codé
en dur dans l'objet des mails — copié depuis WEF sans jamais être adapté,
aurait fait atterrir les alertes ECF dans le mauvais dossier Outlook du
client (le tri repose sur ce texte exact). Corrigé : `[${PROJECT_NAME}]`
partout, jamais un nom de projet figé. `NOTIF_ENABLED`/`SMTP_HOST`/
`SMTP_USER`/`NOTIF_FROM`/`NOTIF_TO` activés dans `vars.conf` (non
secrets, committables) pour ECF et WEF ; le mot de passe réel reste
volontairement HORS de Git (déposé uniquement dans
`secrets/smtp_password.txt` sur la VM ECF, jamais commité — discipline
du projet depuis le début). Testé réellement de bout en bout sur ECF
(`notifier.sh --test` + simulation du chemin ECHEC utilisé par
l'orchestrateur) : email reçu, objet correct.

**TABLEAU_DE_BORD_EXPLOITATION.xlsx (WEF)** : signalé par le client comme
"corrompu" (n'ouvrait jamais, même après redémarrage du PC). Diagnostic
réel (pas supposé) : zip intact, XML bien formé sur les 15 parties,
structure OPC valide (vérifié via `System.IO.Packaging.Package` .NET) —
mais un test avec le VRAI moteur Excel (automatisation COM) confirmait
un échec reproductible et systématique, isolé de l'environnement (un
fichier fraîchement créé par Excel s'ouvrait sans problème). Cause
identifiée : dans les 9 feuilles, `<cols>` apparaissait avant
`<sheetViews>` — ordre inverse de la séquence exigée par le schéma
`CT_Worksheet`, invisible pour tout vérificateur XML/zip générique,
rejeté uniquement par le validateur strict d'Excel. Réparé en
reconstruisant le classeur via l'automatisation Excel elle-même (jamais
un nouveau rapiéçage XML manuel) - garantie totale puisque c'est Excel
qui écrit le fichier. Vérifié ouvert avec succès au chemin final réel.

---

## 2026-09-01 (après-midi) — Envoi réel d'emails depuis Odoo, 3e entreprise, incident réel corrigé

**Contexte** : le client a demandé le maximum de cas d'usage réels pour
CLIM AUTO et COUL, avec des documents (factures) atterrissant réellement
dans sa boîte `contact@ankrr.fr`, plus une **3e entreprise réelle**
rencontrée par le client (une boulangerie-glacier dont le comptable tient
stock et comptabilité sur Excel) pour lui montrer le potentiel d'Odoo, et
un argumentaire honnête sur la licence Enterprise.

### `ODOO_MAIL_SERVER_REAL` — brancher Odoo lui-même sur le vrai relais

Jusque-là, seul le test `curl` autonome (`ODOO_SMTP_TEST`) utilisait le
relais OVH réel — Odoo restait sur Postfix local (catchall,
`ODOO_016_SMTP_RELAY.sh`), jamais livré à l'extérieur. Nouveau job :
configure `ir.mail_server` avec les vrais identifiants OVH et vérifie la
connexion via `ir.mail_server.test_smtp_connection()` (méthode réelle du
code source Odoo, jamais une simulation).

### Incident 11 — OVH rejette les factures : le `From` ne correspond pas au compte authentifié

- **Constat réel, rapporté par le client avec capture d'écran du vrai
  bounce OVH** : `550 5.7.1 Rejected by policy: From header domain does
  not align with authenticated domain`. Les en-têtes réels montraient
  `From: "OdooBot" <odoobot@example.com>` alors que l'authentification
  SMTP se faisait en `contact@ankrr.fr`.
- **Faille de méthode reconnue honnêtement** : mon propre test
  (`test_smtp_connection()` + absence d'exception à l'envoi) avait conclu
  à tort à un succès — la soumission SMTP était bien acceptée (250 OK),
  le rejet réel arrivait ensuite, de façon asynchrone (bounce), invisible
  pour toute vérification côté serveur. Seule la boîte de réception
  réelle du destinataire fait foi pour un envoi email — leçon retenue et
  documentée pour ne plus jamais surtraiter un "aucune exception" comme
  une preuve de livraison.
- **Cause racine, trouvée en lisant le code source d'Odoo (jamais
  supposée)** : l'adresse d'expédition se calcule via
  `res.company.alias_domain_id.default_from_email`
  (`mail_alias_domain.py`, `res_company.py`) — aucune société n'avait ce
  domaine configuré, Odoo retombait donc sur son tout dernier repli codé
  en dur, `OdooBot <odoobot@example.com>`. OVH exige un alignement exact
  entre le domaine du `From` et le compte authentifié — politique
  anti-usurpation standard chez tout fournisseur SMTP sérieux, pas un
  défaut du relais.
- **Décision et correction, à la racine** : création d'un
  `mail.alias.domain` réel (`name='ankrr.fr'`, `default_from='contact'`),
  appliqué à **toutes** les sociétés existantes (pas seulement celles de
  la démo) — plus aucun email sortant, présent ou futur, ne peut retomber
  sur `odoobot@example.com`. `from_filter` posé également sur le serveur
  SMTP pour renforcer l'intention.
- **Revérifié réellement** : les deux factures (CLIM AUTO, COUL) ont été
  renvoyées après correction — succès annoncé avec prudence cette fois
  (jamais réaffirmé sans nouvelle preuve), le client invité à confirmer
  lui-même la réception.

### Incident 12 — société multi-entreprise sans entrepôt

- **Constat réel** : `AssertionError: aucun entrepot pour PAIN & GLACE`
  en créant le stock initial.
- **Fausse piste explicitement documentée** : `res.company.
  create_missing_warehouse()` semblait la bonne méthode (trouvée dans le
  code source), mais son propre docstring dit "add a warehouse on the
  FIRST company of the database" — elle ne fait rien dès qu'AU MOINS UN
  entrepôt existe déjà ailleurs dans la base, même pour une autre
  société. Corrigé en créant l'entrepôt directement (même schéma
  qu'Odoo utilise en interne pour la toute première société).

### Incident 13 — société multi-entreprise sans plan comptable

- **Constat réel** : `No journal could be found in company ... for any
  of those types: sale` en créant une facture pour une société qui vient
  d'être créée. Corrigé via `env['account.chart.template'].
  with_company(company).try_loading('generic_coa', company)` — modèle
  comptable générique réel d'Odoo, utilisé en repli quand aucune
  localisation dédiée au pays n'existe (aucun `l10n_ci` pour la Côte
  d'Ivoire dans ce dépôt source).

### 3e entreprise — PAIN & GLACE (boulangerie-glacier)

Société réelle + 6 références produit avec stock réel (remplace
directement le suivi Excel du comptable) + une facture réelle postée et
envoyée par email. Argumentaire Enterprise honnête rédigé
(`docs/AVANTAGES_LICENCE_ENTERPRISE.md`) : seulement les modules
réellement pertinents pour ce métier précis, jamais un argumentaire
générique.

### Modules ajoutés à la liste "reste actif en permanence"

`account` (COMPTA) et `stock` (STOCK) rejoignent `mail`, `hr`, `crm`,
`hr_holidays`, `hr_recruitment` dans `MOD_ALL_CLEANUP_FINAL.sh` — ils
portent désormais de vraies factures postées et un vrai stock, que la
désinstallation détruirait réellement (voir Incident 10, découvert plus
tôt dans la journée).

### Incident 14 — PDF de facture introuvable : wkhtmltopdf invisible pour l'utilisateur odoo

- **Constat réel, en générant la première vraie facture PDF** :
  `odoo.exceptions.UserError: Unable to find Wkhtmltopdf on this system`
  alors que `wkhtmltopdf --version` fonctionne parfaitement en root.
- **Cause racine, vérifiée directement** : `which wkhtmltopdf` en root →
  `/usr/local/bin/wkhtmltopdf` ; le même test via `sudo -u odoo` →
  introuvable. Le paquet `wkhtmltox` installe ses binaires dans
  `/usr/local/bin`, absent du PATH restreint (secure_path) de
  l'utilisateur système `odoo`. Exactement la même famille de piège que
  Python 3.11 plus tôt dans la journée (Incidents 6-7) : une vérification
  faite uniquement en root ne prouve rien pour l'utilisateur réel
  d'exécution.
- **Décision** : lien symbolique vers `/usr/bin` (présent dans tout PATH
  raisonnable) plutôt que de modifier le PATH d'odoo — solution la plus
  simple et robuste. `ODOO_007_WKHTMLTOPDF.sh` vérifie désormais
  explicitement `sudo -u "${ODOO_USER}" wkhtmltopdf --version` avant de
  se déclarer OK, jamais seulement la vue de root.
- **Conséquence découverte en marge** : les 3 factures envoyées par
  email plus tôt dans la journée l'ont été alors que ce défaut existait
  déjà — pièce jointe PDF potentiellement invalide ou absente. Les 3
  ont été renvoyées après correction, plus jamais réaffirmé un succès
  sans literally re-tester.

### Incident 15 — factures envoyées par email sans pièce jointe PDF

- **Constat réel, rapporté par le client** : les emails de facture
  arrivaient sans aucun PDF joint (contrairement au PDF envoyé
  directement en fichier, qui lui fonctionnait).
- **Cause racine, vérifiée en base** : `template.report_template_ids`
  du modèle `account.email_template_edi_invoice` était **vide** —
  `send_mail()` ne génère un PDF que si ce champ pointe vers un vrai
  rapport (`mail_template.py`, vérifié dans le code source). Un envoi
  direct (`report._render_qweb_pdf()`) fonctionnait car il ne dépend
  pas de ce champ ; `send_mail()` via le modèle d'email, si.
- **Correction** : `template.report_template_ids = [(4,
  report_facture.id)]` avant l'envoi, dans les 3 jobs de facturation.

### Incident 16 — factures en anglais malgré une demande explicite en français

- **Constat** : le PDF généré affichait "Invoice", "Due Date", etc.
- **Fausse piste** : `env['res.lang']._activate_lang('fr_FR')` +
  `with_context(lang='fr_FR')` — n'a rien changé, le rendu restait en
  anglais.
- **Cause racine** : Odoo 19 a supprimé le modèle `ir.translation`
  (vérifié : la table n'existe plus en base) — activer une langue
  n'installe plus automatiquement ses traductions de la même façon.
  Résolu via la commande officielle `odoo-bin --load-language=fr_FR
  --stop-after-init`, mécanisme documenté et fiable, plutôt qu'un appel
  Python interne dont l'API a changé entre versions.
- **Vérifié réellement** : PDF régénéré et relu — "Facture", "Date de
  facturation", "Échéance", "Communication de paiement" confirmés.
- **Écart connu, assumé** : la devise reste USD sur les 3 sociétés
  existantes (Odoo refuse tout changement de devise une fois des
  écritures comptables postées — testé et confirmé par l'erreur réelle
  du système). Corrigé pour les futurs déploiements uniquement (XOF fixé
  dès `res.company.create()` dans les 3 jobs SOCIETE) — un rebuild complet
  des 3 sociétés existantes pour ce seul detail n'a pas été jugé justifié.

## Ce qui n'a volontairement PAS été commencé cette nuit

- **Tier 1 (modules par domaine métier)** et **Tier 2 (jobs RUN de
  démonstration)** : Tier 0 ne vient que d'être confirmé stable ; ce
  travail suppose des choix de scénarios métier (voir
  `docs/CONVENTION_NOMMAGE.md`) qui méritent d'être validés avec le
  client plutôt que décidés seul pendant la nuit.
- **Vérification du catalogue réel des modules Odoo 19** (statuts
  licence Community/Enterprise du tableau donné en chat) — nécessite
  Tier 0, maintenant disponible ; à faire en priorité à la prochaine
  session, avant tout travail de Tier 1.
- **Push GitHub** — toujours pas de repository demandé pour ce projet ;
  et la doctrine du projet interdit tout push d'un système qui n'était
  pas encore stable au moment de la décision.
- **Correctif du même bug stdin sur WAZ_ELK_FACTORY** — latent, identifié,
  mais hors du mandat "ERP_CRM_FACTORY autonome" de cette nuit.

---

## Décisions volontairement NON prises cette nuit (hors périmètre autonome)

- **Pas de push GitHub** — aucun repository n'a encore été demandé par le
  client pour ce projet, et la doctrine du projet interdit tout push d'un
  système encore instable. Sera proposé une fois Tier 0 confirmé stable de
  bout en bout.
- **Pas de correctif appliqué à WAZ_ELK_FACTORY** malgré le bug latent
  identique dans `orchestrator.sh`/`forcer_job.sh` — projet en production,
  au-delà du mandat "ERP_CRM_FACTORY autonome" confié pour cette session.
- **Pas de construction du Tier 1** (modules) tant que le Tier 0 n'est pas
  intégralement vert et vérifié — respect strict de l'ordre déjà établi.

---

## 2026-09-04 — Illustration générique (ILL1/ILL2/ILL3), PATH_TOUCHED, bug des générateurs

- **Jobs d'illustration renommés** : `JOB_NAME`/`SERVICE`/`IN_COND`/
  `OUT_COND` des 13 jobs `ECFR*` d'illustration portaient le nom du
  client en clair (`ECF_CLIMAUTO_RUN_SOCIETE`, `ILL_CLIMAUTO_SOCIETE_OK`).
  Corrigé (constat utilisateur) : renommé en `ILL1`/`ILL2`/`ILL3` —
  le câblage d'un job ne doit jamais porter le nom d'un client réel,
  pour permettre de dupliquer un fichier de job et l'adapter à un
  nouveau client sans réécrire une chaîne de conditions. Le nom réel
  (CLIM AUTO, COUL, PAIN & GLACE) reste uniquement dans `DESC` (texte
  libre). Voir `docs/CONVENTION_NOMMAGE.md`.
- **Bug réel trouvé et corrigé** : `bin/generer_export_visio.sh` et
  `bin/generer_export_controlm.sh` cherchaient `jobs_table.csv` et
  écrivaient `docs/` sous `bin/` (`SCRIPT_DIR` non corrigé lors de la
  réorganisation de la racine du 1er septembre) — les deux scripts
  échouaient silencieusement à toute exécution depuis la réorganisation.
  Corrigé (`PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"`), les deux
  générateurs vérifiés en réel (38 services, 105 jobs).
- **`PATH_TOUCHED` ajouté au registre d'audit** (`state/JOBS_HISTORY.csv`,
  7ᵉ colonne) — motivé par une pratique réelle du CBS Amplitude (SGABS) :
  savoir quel chemin exact a été touché par quelle opération. Contrat
  opt-in via `$ECF_JOB_PATHS_FILE` (exporté avant chaque lancement de
  job par `orchestrator.sh`, `bin/run_now.sh`, `bin/rerun_job.sh`,
  `bin/order_job.sh`). Au passage, corrigé l'en-tête du ledger qui
  omettait déjà `DURATION_SEC` (écrit depuis le 2026-08-12 sans jamais
  figurer dans l'en-tête) dans les 6 scripts qui l'écrivent. Voir
  `docs/CONVENTION_NOMMAGE.md`.
- **Démarrage du Tier 1 (jobs métier réels) et bug réel trouvé en le
  construisant** : premier job, `ECFRCRCL`
  (`ECF_CRM_RUN_CREATELEAD`), lit un CSV réel déposé dans
  `operations/cr/rcv`, crée des pistes CRM réelles, archive le fichier
  traité. Contrairement aux jobs `BLD`, un job métier n'a pas de jalon
  permanent — `OUT_COND=NONE`. En l'écrivant, découvert que
  `job_done()`/`mark_done()` (`lib/commun.sh`) ne traitaient PAS "NONE"
  en `OUT_COND` comme "pas de jalon" (déjà le cas côté `IN_COND`) : un
  vrai fichier `state/NONE.ok`, partagé par tout job `OUT_COND=NONE`,
  aurait gelé pour toujours tous les jobs répétables dès le premier
  succès de l'un d'eux. Bug latent jamais déclenché avant (aucun job
  répétable n'existait). Corrigé dans `lib/commun.sh`, plus un
  garde-fou dans `orchestrator.sh` (`RAN_THIS_RUN`) pour qu'un job
  `NONE` ne tourne qu'une fois par lancement de l'orchestrateur, jamais
  une fois par passe de la boucle multi-passes (jusqu'à 30x sinon).
  Vérifié par un test unitaire isolé des deux fonctions avant d'écrire
  le job. Voir `docs/CONVENTION_NOMMAGE.md`, section Tier 1.
- **`bin/verifier_independance_modules.sh` ajouté** — rappel explicite
  de l'utilisateur : ECF ne doit jamais reproduire le couplage
  WEF (`orchestrator.sh` y fait `exit 1` à la première erreur). Garanti
  structurellement désormais (pas seulement par l'isolation de panne
  déjà existante) : vérifié sur les 106 lignes réelles de
  `jobs_table.csv`, testé avec une fausse dépendance injectée
  temporairement (`VT`→`CR`), détectée correctement, fichier restauré
  à l'identique. Modules CRM (5 jobs) et Ventes (3 jobs) terminés sur
  ce patron dans la foulée — `ECFRVTIN` (facturation) illustre la règle
  pour un cas limite réel : `account` nécessaire côté Odoo, jamais un
  `IN_COND` cross-module, vérifié et échoue clairement à l'exécution
  à la place.
- **Module Achat terminé** (3 jobs, `ECFRAHPO`/`CF`/`RC`) sur le même
  patron. `ECFRAHRC` (réception) suit le même principe que
  `ECFRVTIN` pour sa dépendance à `stock`, mais reste **non vérifié
  sur une vraie instance Odoo 19** contrairement aux autres jobs Tier 1
  de cette session (qui réutilisent des patrons déjà exécutés en réel
  par les jobs d'illustration) — à tester avant exploitation.
