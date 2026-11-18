# B2 · Catalogue Node.js, PostgreSQL et Redis

Objectif : déployer avec OpenTofu une API Node.js qui lit PostgreSQL puis sert la même réponse depuis Redis.

```text
Client HTTP --3000--> API Node.js --5432--> PostgreSQL (volume infra-si-catalogue-pg)
                                  --6379--> Redis      (volume infra-si-catalogue-redis)
```

## Prérequis

- Moteur Docker démarré, OpenTofu installé.
- Port `3000` libre sur la boucle locale de l'hôte. Les ports `5432` et `6379` ne sont pas publiés : ils restent internes au réseau `infra-si-catalogue-net`.

## Fichiers

| Fichier | Rôle | Versionné |
| :--- | :--- | :--- |
| `api/package.json`, `api/Dockerfile`, `api/server.js` | API : `/health` teste la base et le cache ; `/products` indique si la réponse vient de `postgresql` ou de `redis` (cache de 30 s). | oui |
| `versions.tf` | Fournisseur `kreuzwerker/docker`. | oui |
| `variables.tf` | Port, identifiant de l'image, nom, utilisateur et mot de passe de la base (`sensitive`). | oui |
| `main.tf` | Réseau, 2 volumes, 2 images, conteneurs PostgreSQL et Redis avec contrôle de santé, conteneur API, sortie `api_url`. | oui |
| `terraform.tfvars.example` | Modèle des valeurs locales. | oui |
| `.terraform.lock.hcl` | Version et empreintes du fournisseur. | oui |
| `terraform.tfvars` | Valeurs réelles : identifiant de l'image et mot de passe. | non (`.gitignore`) |
| `terraform.tfstate*`, `.terraform/`, `*.tfplan` | État (il contient le mot de passe en clair), cache, plans. | non (`.gitignore`) |

Écart au support : fournisseur en `3.9.0` au lieu de `3.6.1`, que OpenTofu refuse (signature d'émetteur inconnu). Le détail est dans le [README de B1](../b1-nginx-opentofu/README.md#écart-au-support--version-du-fournisseur).

## Commandes

Depuis ce dossier. L'image de l'API est construite par Docker ; OpenTofu crée le réseau, les volumes et les conteneurs.

```bash
docker build -t infra-si-catalogue-api:lab ./api
docker image inspect --format "{{.Id}}" infra-si-catalogue-api:lab
cp terraform.tfvars.example terraform.tfvars   # puis y coller l'identifiant sha256 complet et un mot de passe local
tofu init
tofu fmt
tofu validate
tofu plan -out=catalogue.tfplan
tofu show catalogue.tfplan
tofu apply catalogue.tfplan
tofu output api_url
```

Vérifier les données et le cache (sous PowerShell, utiliser `curl.exe`) :

```bash
curl -fsS http://127.0.0.1:3000/health
curl -fsS http://127.0.0.1:3000/products
curl -fsS http://127.0.0.1:3000/products
docker logs infra-si-catalogue-api
docker exec infra-si-catalogue-db psql -U catalogue -d catalogue -c "INSERT INTO products VALUES (3, 'Ecran') ON CONFLICT DO NOTHING;"
docker restart infra-si-catalogue-db
# attendre plus de 30 s (expiration du cache), puis :
curl -fsS http://127.0.0.1:3000/products
```

Remplacer le conteneur de base en gardant le volume :

```bash
tofu apply -replace=docker_container.postgres
# attendre plus de 30 s, puis :
curl -fsS http://127.0.0.1:3000/products
```

## Résultats attendus

- `/health` renvoie HTTP 200 avec `{"database":"ok","redis":"ok"}`.
- Sur une pile neuve, le premier `/products` lit `postgresql` ; le second, moins de 30 s plus tard, renvoie les mêmes produits depuis `redis`.
- Le produit 3 inséré n'apparaît pas tant que le cache est valide. Après expiration, il est relu depuis `postgresql`, y compris après le redémarrage de la base.
- Après remplacement du conteneur de base, le produit 3 est toujours présent.

### Redémarrage ou remplacement : ce que chacun démontre

- **`docker restart`** arrête et relance **le même conteneur**. Le service tolère donc une interruption, et l'API se reconnecte d'elle-même (le pool `pg` rouvre ses connexions). En revanche, cela ne prouve pas que les données sont dans le volume : elles survivraient aussi dans la couche du conteneur, qui n'est pas effacée.
- **Le remplacement** (`tofu apply -replace=…`) détruit le conteneur et en crée un **nouveau**, avec un autre identifiant, sur le même volume nommé. Si le produit 3 est toujours là, c'est qu'il vit dans le volume `infra-si-catalogue-pg` et non dans le conteneur. C'est ce que vaut une mise à jour d'image de PostgreSQL.

## Preuves

Exécution du 2026-11-18 : OpenTofu v1.13.9, `kreuzwerker/docker` v3.9.0, Docker Engine 29.2.0.

Construction, plan et application :

```text
$ docker build -t infra-si-catalogue-api:lab ./api
#8 3.053 added 24 packages, and audited 25 packages in 2s
#10 naming to docker.io/library/infra-si-catalogue-api:lab done
$ docker image inspect --format "{{.Id}}" infra-si-catalogue-api:lab
sha256:34ff1a7c31bd7548b065a21df9f76315d336fd5371b27f0d4a44b81e7ef79f9f
$ tofu validate
Success! The configuration is valid.
$ tofu plan -out=catalogue.tfplan
  # docker_container.api will be created
  # docker_container.postgres will be created
  # docker_container.redis will be created
  # docker_image.postgres will be created
  # docker_image.redis will be created
  # docker_network.catalogue will be created
  # docker_volume.postgres will be created
  # docker_volume.redis will be created
Plan: 8 to add, 0 to change, 0 to destroy.
$ tofu show catalogue.tfplan   (extrait : le mot de passe n'est pas affiché)
      + env                                         = (sensitive value)
$ tofu apply catalogue.tfplan
docker_container.redis: Creation complete after 5s
docker_container.postgres: Creation complete after 5s
docker_container.api: Creation complete after 1s
Apply complete! Resources: 8 added, 0 changed, 0 destroyed.
$ tofu output api_url
"http://127.0.0.1:3000"
$ docker ps --filter name=infra-si-catalogue
NAMES                      STATUS                    PORTS
infra-si-catalogue-api     Up Less than a second     127.0.0.1:3000->3000/tcp
infra-si-catalogue-db      Up 5 seconds (healthy)    5432/tcp
infra-si-catalogue-cache   Up 11 seconds (healthy)   6379/tcp
```

L'API n'est créée qu'après que PostgreSQL et Redis sont `healthy`, grâce à `wait = true` et `depends_on`.

Lecture PostgreSQL puis Redis :

```text
$ curl -fsS http://127.0.0.1:3000/health
{"database":"ok","redis":"ok"}  [HTTP 200]
$ curl -fsS http://127.0.0.1:3000/products
{"source":"postgresql","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
$ curl -fsS http://127.0.0.1:3000/products
{"source":"redis","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
$ docker logs infra-si-catalogue-api
(aucune ligne : pas d'erreur de connexion)
```

Ajout d'un produit, redémarrage de la base, expiration du cache :

```text
$ docker exec infra-si-catalogue-db psql -U catalogue -d catalogue -c "INSERT INTO products VALUES (3, 'Ecran') ON CONFLICT DO NOTHING;"
INSERT 0 1
$ curl -fsS http://127.0.0.1:3000/products   # cache encore valide : Ecran pas encore visible
{"source":"redis","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"}]}
$ docker restart infra-si-catalogue-db
infra-si-catalogue-db
état base : healthy
$ curl -fsS http://127.0.0.1:3000/products   # après expiration du cache (30 s)
{"source":"postgresql","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"},{"id":3,"name":"Ecran"}]}
$ curl -fsS http://127.0.0.1:3000/health
{"database":"ok","redis":"ok"}  [HTTP 200]
```

Remplacement du conteneur de base, même volume :

```text
$ docker ps --filter name=infra-si-catalogue-db -q   (avant)
71f53e153a56
$ tofu apply -replace=docker_container.postgres
  # docker_container.postgres will be replaced, as requested
Plan: 1 to add, 0 to change, 1 to destroy.
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
$ docker ps --filter name=infra-si-catalogue-db -q   (après)
ecaaceaa25fb
$ curl -fsS http://127.0.0.1:3000/products   # nouveau conteneur, même volume
{"source":"postgresql","products":[{"id":1,"name":"Clavier"},{"id":2,"name":"Souris"},{"id":3,"name":"Ecran"}]}  [HTTP 200]
$ tofu plan
No changes. Your infrastructure matches the configuration.
```

Conclusion : les deux lectures montrent le cache à l'œuvre (`postgresql` puis `redis`), et la réponse servie par le cache est en retard sur la base tant qu'il n'a pas expiré. Le produit 3 survit au redémarrage et au remplacement du conteneur : il est stocké dans le volume.

## Nettoyage

Les volumes PostgreSQL et Redis sont gérés par OpenTofu : le plan de destruction les supprime. Il faut donc sauvegarder avant les données à conserver.

```bash
tofu plan -destroy -out=catalogue-destroy.tfplan
tofu show catalogue-destroy.tfplan
tofu apply catalogue-destroy.tfplan
docker ps -a --filter name=infra-si-catalogue
rm -f catalogue.tfplan catalogue-destroy.tfplan
```

Résultat obtenu :

```text
Plan: 0 to add, 0 to change, 8 to destroy.
Apply complete! Resources: 0 added, 0 changed, 8 destroyed.
$ docker ps -a --filter name=infra-si-catalogue
NAMES     STATUS
$ docker volume ls --filter name=infra-si-catalogue
DRIVER    VOLUME NAME
$ docker image ls infra-si-catalogue-api
REPOSITORY               TAG       IMAGE ID
infra-si-catalogue-api   lab       34ff1a7c31bd
```

Conteneurs, réseau et volumes ont disparu. L'image de l'API, construite hors d'OpenTofu, reste disponible. Relancer `tofu apply` à partir de ces fichiers reconstruit la pile sur des volumes neufs.
