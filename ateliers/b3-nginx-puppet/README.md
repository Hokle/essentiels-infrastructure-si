# B3 · Configurer Nginx avec Puppet

Objectif : installer Nginx avec un module Puppet et vérifier que la seconde application ne change rien.

> **Écart au support.** Le support applique le module dans la VM `UbuntuDev`. Cette VM ne démarre pas sur ce poste (voir [A2](../a2-vm-linux-conteneur-web/README.md#résultat-obtenu)), donc l'atelier tourne sur une **cible de remplacement** : un conteneur Ubuntu 24.04 joint par SSH, avec un compte `infra` sudo, comme la VM. Le module Puppet est identique. Seule différence : le conteneur n'a pas systemd, donc Puppet gère le service par les scripts `/etc/init.d` (fournisseur `debian`) au lieu de `systemctl`.

## Contenu

| Fichier | Rôle |
| :--- | :--- |
| [`site.pp`](site.pp) | manifeste principal, inclut la classe `web_nginx` |
| [`modules/web_nginx/manifests/init.pp`](modules/web_nginx/manifests/init.pp) | paquet `nginx`, page `/var/www/html/puppet.html` en `0644`, service `nginx` démarré et activé |
| [`cible/Dockerfile`](cible/Dockerfile) | cible de remplacement : Ubuntu 24.04, OpenSSH, Python 3, compte `infra` sudo par clé ; réutilisée par B4 |

## Prérequis

- Docker, et une paire de clés SSH dédiée au labo (ici `~/.ssh/infra_si_lab`, hors dépôt).
- Puppet s'installe dans la cible : paquet `puppet-agent` d'Ubuntu 24.04 (Puppet 8.4.0).

## Commandes

Cible de remplacement, ports publiés sur la boucle locale seulement :

```bash
docker build -t infra-si-cible:24.04 --build-arg SSH_PUBKEY="$(cat ~/.ssh/infra_si_lab.pub)" ./cible
docker run -d --name infra-si-cible --hostname ubuntu-cible \
  -p 127.0.0.1:2223:22 -p 127.0.0.1:8081:80 infra-si-cible:24.04
ssh -i ~/.ssh/infra_si_lab -p 2223 infra@127.0.0.1 'hostname; sudo -n true && echo sudo-ok'
```

Copie du module et installation de Puppet :

```bash
tar cf - site.pp modules | ssh -i ~/.ssh/infra_si_lab -p 2223 infra@127.0.0.1 'mkdir -p ~/b3 && tar xf - -C ~/b3'
ssh -i ~/.ssh/infra_si_lab -p 2223 infra@127.0.0.1
sudo apt-get update && sudo apt-get install -y puppet-agent
```

Dans la cible, depuis `~/b3` :

```bash
puppet parser validate site.pp modules/web_nginx/manifests/init.pp
sudo puppet apply --modulepath=modules --noop site.pp
sudo puppet apply --modulepath=modules --detailed-exitcodes site.pp; echo rc=$?
curl -s http://127.0.0.1/puppet.html
sudo puppet apply --modulepath=modules --detailed-exitcodes site.pp; echo rc=$?
```

Avec `--detailed-exitcodes`, le code de retour vaut `2` quand des changements ont été appliqués et `0` quand tout était déjà conforme.

## Résultats attendus

- `--noop` annonce les trois changements sans les faire.
- La première application installe Nginx, crée la page et démarre le service (`rc=2`).
- La seconde application ne change rien (`rc=0`, aucune ligne de ressource).
- Une dérive faite à la main est corrigée à l'application suivante.

## Preuves

Obtenues le 2026-11-18 vers 13:40 (l'horloge du conteneur est en UTC). Cible : `Ubuntu 24.04.5 LTS`, Python 3.12.3, Puppet 8.4.0.

Validation et simulation :

```text
validate-ok
Notice: Compiled catalog for ubuntu-cible in environment production in 0.65 seconds
Notice: /Stage[main]/Web_nginx/Package[nginx]/ensure: current_value 'purged', should be 'present' (noop)
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/ensure: current_value 'absent', should be 'file' (noop)
Notice: /Stage[main]/Web_nginx/Service[nginx]/ensure: current_value 'stopped', should be 'running' (noop)
Notice: Class[Web_nginx]: Would have triggered 'refresh' from 3 events
Notice: Applied catalog in 2.70 seconds
```

Première application :

```text
Notice: /Stage[main]/Web_nginx/Package[nginx]/ensure: created
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/ensure: defined content as '{sha256}923fb12d92ff2426f94be4ed8402094b5a06be6978b0be16831f0ba646a2dd68'
Notice: /Stage[main]/Web_nginx/Service[nginx]/ensure: ensure changed 'stopped' to 'running'
Notice: Applied catalog in 19.98 seconds
rc=2
```

Contrôle dans la cible, puis depuis l'hôte par le port publié :

```text
-rw-r--r-- 1 root root 32 Nov 18 12:41 /var/www/html/puppet.html
 * nginx is running
200 Configuration geree avec Puppet        # http://127.0.0.1/puppet.html (cible)
200 Configuration geree avec Puppet        # http://127.0.0.1:8081/puppet.html (hôte)
```

Seconde application, **idempotente** :

```text
Notice: Compiled catalog for ubuntu-cible in environment production in 0.44 seconds
Notice: Applied catalog in 1.82 seconds
rc=0
```

Dérive manuelle (contenu modifié, droits en `0666`, service arrêté), puis correction :

```text
-rw-rw-rw- 1 root root 18 Nov 18 12:41 /var/www/html/puppet.html
 * nginx is not running
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/content: content changed '{sha256}1624160f…' to '{sha256}923fb12d…'
Notice: /Stage[main]/Web_nginx/File[/var/www/html/puppet.html]/mode: mode changed '0666' to '0644'
Notice: /Stage[main]/Web_nginx/Service[nginx]/ensure: ensure changed 'stopped' to 'running'
rc=2
-rw-r--r-- 1 root root 32 Nov 18 12:42 /var/www/html/puppet.html
 * nginx is running
```

Fournisseur retenu par Puppet dans le conteneur (pas de systemd) :

```text
service { 'nginx':
  ensure   => 'running',
  enable   => 'true',
  provider => 'debian',
}
```

## Nettoyage

La cible sert encore à B4. Ensuite :

```bash
docker rm -f infra-si-cible
docker image rm infra-si-cible:24.04
```
