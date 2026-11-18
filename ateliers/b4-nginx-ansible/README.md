# B4 · Déployer Nginx avec Ansible

Objectif : appliquer un playbook Nginx par SSH et vérifier que la seconde exécution indique changed=0.

> **Écart au support.** Le support vise la VM `UbuntuDev` en `192.168.56.20` ([`inventory.ini`](inventory.ini)). Cette VM ne démarre pas sur ce poste (voir [A2](../a2-vm-linux-conteneur-web/README.md#résultat-obtenu)), donc le playbook tourne sur la **cible de remplacement** de B3 ([`../b3-nginx-puppet/cible/Dockerfile`](../b3-nginx-puppet/cible/Dockerfile)) : Ubuntu 24.04, SSH par clé, compte `infra` sudo. Une instance neuve est lancée pour B4, sans le Nginx installé par Puppet. Le playbook est identique ; seul l'inventaire change ([`inventory-cible.ini`](inventory-cible.ini)).

## Contenu

| Fichier | Rôle |
| :--- | :--- |
| [`web.yml`](web.yml) | playbook : paquet `nginx` (cache apt valable 1 h), page `/var/www/html/ansible.html` en `0644`, service démarré et activé |
| [`inventory.ini`](inventory.ini) | inventaire du support, VM en `192.168.56.20` |
| [`inventory-cible.ini`](inventory-cible.ini) | inventaire utilisé ici, cible sur `127.0.0.1:2224` |

## Prérequis

- Ansible côté contrôleur (ici `ansible [core 2.14.18]`, paquet Debian 12 dans WSL).
- Côté cible : SSH et Python 3, rien d'autre. Ansible n'installe pas d'agent.
- La clé SSH du labo (ici `~/.ssh/infra_si_lab`, hors dépôt).

## Commandes

Cible neuve, depuis le dossier de B3 :

```bash
docker run -d --name infra-si-cible-b4 --hostname ubuntu-cible-b4 \
  -p 127.0.0.1:2224:22 -p 127.0.0.1:8082:80 infra-si-cible:24.04
```

Depuis ce dossier :

```bash
K="--private-key ~/.ssh/infra_si_lab"
ansible-playbook -i inventory-cible.ini web.yml --syntax-check
ansible -i inventory-cible.ini targets -m ansible.builtin.ping $K
ansible-playbook -i inventory-cible.ini web.yml $K          # 1re exécution
ansible-playbook -i inventory-cible.ini web.yml $K          # 2e exécution : changed=0
ansible-playbook -i inventory-cible.ini web.yml --check --diff $K
curl -s http://127.0.0.1:8082/ansible.html
```

Sur la VM du support, remplacer `inventory-cible.ini` par `inventory.ini`.

## Résultats attendus

- `ping` répond `pong` : SSH, sudo et Python sont prêts.
- La première exécution change 3 tâches, la seconde aucune (`changed=0`).
- `--check --diff` ne montre aucune différence sur une cible conforme, et montre la différence quand on a modifié la cible.

## Preuves

Obtenues le 2026-11-18 vers 13:44 (l'horloge du conteneur est en UTC).

Préparation :

```text
playbook: web.yml
ubuntu-cible | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

Première exécution :

```text
TASK [Gathering Facts] *********************************************************
ok: [ubuntu-cible]
TASK [Installer Nginx] *********************************************************
changed: [ubuntu-cible]
TASK [Déployer une page de test] ***********************************************
changed: [ubuntu-cible]
TASK [Activer et démarrer Nginx] ***********************************************
changed: [ubuntu-cible]
PLAY RECAP *********************************************************************
ubuntu-cible               : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Seconde exécution, **idempotente**, puis `--check --diff` sans différence :

```text
ubuntu-cible               : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
ubuntu-cible               : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Contrôle dans la cible (module `shell` avec `-b`), puis depuis l'hôte :

```text
-rw-r--r-- 1 root root 33 Nov 18 12:43 /var/www/html/ansible.html
 * nginx is running
200
200 Configuration geree avec Ansible        # http://127.0.0.1:8082/ansible.html (hôte)
```

Dérive manuelle (contenu modifié, Nginx arrêté), vue par `--check --diff`, puis corrigée :

```text
--- before: /var/www/html/ansible.html
+++ after: …/tmp…
-modifie
+Configuration geree avec Ansible
ubuntu-cible               : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
200 Configuration geree avec Ansible
```

Observation : un `--check` lancé **avant** la première exécution, sur la cible neuve, s'est terminé en `failed=1`. Cause probable (inférée, message non relevé) : en mode `--check`, le module `apt` ne rafraîchit pas réellement le cache, et le paquet `nginx` reste introuvable sur une image sans liste de paquets. Sur une cible déjà configurée, `--check` fonctionne, comme le montrent les sorties ci-dessus.

## Comparaison avec Puppet

| Critère | Puppet (B3) | Ansible (B4) |
| :--- | :--- | :--- |
| Sur la cible | agent `puppet-agent` installé (Ruby embarqué) | SSH et Python 3 seulement |
| Déclenchement | `puppet apply` lancé **sur** la cible (ou agent périodique avec un serveur) | `ansible-playbook` lancé **depuis** le contrôleur, par SSH |
| Langage | DSL déclaratif ; l'ordre se déclare (`require`) | YAML ; les tâches s'exécutent dans l'ordre du fichier |
| Simulation | `--noop` | `--check --diff` |
| Idempotence prouvée | 2ᵉ `apply` : aucune ressource, `rc=0` | 2ᵉ exécution : `changed=0` |
| Dérive manuelle | corrigée au prochain `apply` (contenu, droits, service) | corrigée à la prochaine exécution (contenu, service) |
| Usage typique | parc nombreux maintenu en conformité dans la durée | déploiement et orchestration ponctuels, sans agent |

Dans les deux cas, l'idempotence vient des modules : ils comparent l'état réel à l'état voulu et n'agissent que sur l'écart.

## Nettoyage

```bash
docker rm -f infra-si-cible-b4 infra-si-cible
docker image rm infra-si-cible:24.04
```
