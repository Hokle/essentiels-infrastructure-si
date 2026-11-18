# B1 · Déployer Nginx avec OpenTofu

Objectif : examiner un plan, appliquer les changements, lire l'état et retirer les ressources.

## Prérequis

- OpenTofu installé (`tofu version`).
- Moteur Docker démarré (`docker version`). Le fournisseur se connecte au socket local `/var/run/docker.sock`.
- Port `8080` libre sur la boucle locale de l'hôte.

## Fichiers

| Fichier | Rôle | Versionné |
| :--- | :--- | :--- |
| `main.tf` | Fournisseur Docker, image `nginx:1.28-alpine`, conteneur `infra-si-nginx` publié sur `127.0.0.1:8080`, sortie `nginx_url`. | oui |
| `.terraform.lock.hcl` | Version et empreintes du fournisseur retenu, pour réinstaller exactement le même. | oui |
| `.terraform/`, `terraform.tfstate*`, `*.tfplan` | Cache des fournisseurs, état local, plans enregistrés. | non (`.gitignore`) |

### Écart au support : version du fournisseur

Le support fixe `kreuzwerker/docker` en `3.6.1`. Sur ce poste (OpenTofu v1.13.9), `tofu init` refuse cette version :

```text
Error while installing kreuzwerker/docker v3.6.1: the provider is not signed
with a valid signing key; please contact the provider author (authentication
signature from unknown issuer)
```

Les versions 3.4.0, 3.5.0, 3.6.0 et 3.6.2 échouent de la même façon. À partir de 3.7.0, elles s'installent, signées par la clé `0DCE698927DAF8EC`, celle que publie le registre OpenTofu. Les anciennes versions ont été signées avec une clé que le registre ne référence plus. Je n'ai pas désactivé la vérification de signature. J'ai retenu **3.9.0**, la dernière version de la branche 3.x : même version majeure, donc pas de changement cassant attendu pour les ressources utilisées ici. Le résultat, décrit plus bas, est conforme à l'attendu du support.

## Commandes

Depuis ce dossier :

```bash
tofu init
tofu fmt
tofu validate
tofu plan -out=nginx.tfplan
tofu show nginx.tfplan
tofu apply nginx.tfplan
tofu output nginx_url
docker ps --filter name=infra-si-nginx
tofu state list
curl -sI http://127.0.0.1:8080
tofu plan
```

En cas de port occupé, changer `external` **et** la sortie `nginx_url`, puis replanifier.

## Résultats attendus

- `tofu plan` annonce `2 to add` : l'image et le conteneur.
- Après `apply`, `tofu output` donne l'URL, le conteneur `infra-si-nginx` tourne, et `tofu state list` liste les deux ressources.
- `http://127.0.0.1:8080` répond `200 OK` avec la page Nginx.
- Un second `tofu plan` affiche `No changes` : l'infrastructure réelle correspond à la configuration, et réappliquer ne produirait aucun effet (idempotence).
- Après le plan de destruction, le conteneur a disparu, mais l'image reste dans le cache Docker grâce à `keep_locally = true`.

## Preuves

Exécution du 2026-11-18 : OpenTofu v1.13.9, `kreuzwerker/docker` v3.9.0, Docker Engine 29.2.0.

Initialisation et plan :

```text
$ tofu init
- Installing kreuzwerker/docker v3.9.0...
- Installed kreuzwerker/docker v3.9.0 (signed, key ID 0DCE698927DAF8EC)
OpenTofu has been successfully initialized!
$ tofu validate
Success! The configuration is valid.
$ tofu plan -out=nginx.tfplan
  # docker_container.nginx will be created
  # docker_image.nginx will be created
Plan: 2 to add, 0 to change, 0 to destroy.
$ tofu show nginx.tfplan   (extrait)
  # docker_container.nginx will be created
      + name     = "infra-si-nginx"
          + external = 8080
          + internal = 80
          + ip       = "127.0.0.1"
  # docker_image.nginx will be created
      + name     = "nginx:1.28-alpine"
  + nginx_url = "http://127.0.0.1:8080"
```

Application et vérification :

```text
$ tofu apply nginx.tfplan
docker_image.nginx: Creation complete after 4s
docker_container.nginx: Creation complete after 1s [id=c91c163bc0c4…]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
$ tofu output nginx_url
"http://127.0.0.1:8080"
$ docker ps --filter name=infra-si-nginx
NAMES            IMAGE          STATUS                  PORTS
infra-si-nginx   a8b39bd9cf0f   Up Less than a second   127.0.0.1:8080->80/tcp
$ tofu state list
docker_container.nginx
docker_image.nginx
$ curl -sI http://127.0.0.1:8080
HTTP/1.1 200 OK
Server: nginx/1.28.3
$ curl -s http://127.0.0.1:8080 | grep -o "<title>.*</title>"
<title>Welcome to nginx!</title>
$ tofu plan
No changes. Your infrastructure matches the configuration.
```

Destruction après lecture du plan :

```text
$ tofu plan -destroy -out=nginx-destroy.tfplan
  # docker_container.nginx will be destroyed
  # docker_image.nginx will be destroyed
Plan: 0 to add, 0 to change, 2 to destroy.
$ tofu apply nginx-destroy.tfplan
docker_container.nginx: Destruction complete
docker_image.nginx: Destruction complete
Apply complete! Resources: 0 added, 0 changed, 2 destroyed.
$ docker ps -a --filter name=infra-si-nginx
NAMES     STATUS
$ docker image ls nginx:1.28-alpine
REPOSITORY   TAG           IMAGE ID
nginx        1.28-alpine   a8b39bd9cf0f
```

Conclusion : le conteneur a disparu (liste vide). L'image `a8b39bd9cf0f` est toujours dans le cache local : `keep_locally` retire la ressource de l'état sans supprimer l'image de Docker.

## Nettoyage

```bash
tofu plan -destroy -out=nginx-destroy.tfplan
tofu show nginx-destroy.tfplan
tofu apply nginx-destroy.tfplan
docker ps -a --filter name=infra-si-nginx
rm -f nginx.tfplan nginx-destroy.tfplan
```

L'état local (`terraform.tfstate`, désormais vide de ressources) reste hors dépôt. Les plans enregistrés sont supprimés après usage.
