# A1 · MongoDB avec Docker

Objectif : démarrer MongoDB avec Compose, l'interroger dans son conteneur et vérifier que les données survivent au remplacement du conteneur.

## Prérequis

- Moteur Docker démarré (Docker Desktop avec intégration WSL, ou Docker Engine sur Linux).
- `docker version` et `docker compose version` répondent depuis le terminal utilisé.
- Port `27018` libre sur la boucle locale de l'hôte. Le support publie `27017`, mais sur ce poste un MongoDB natif (service Windows `mongod.exe`) occupe déjà `127.0.0.1:27017` : `docker compose up` échouait avec `ports are not available: exposing port TCP 127.0.0.1:27017`. Seul le port côté hôte change ; dans le conteneur, MongoDB écoute toujours sur `27017`.

Les identifiants `root` / `example` sont propres à l'exercice : ce ne sont pas des secrets réels. Ils ne servent qu'à l'initialisation d'un volume vierge ; les modifier ensuite ne change pas le compte déjà créé.

## Commandes

Toutes les commandes s'exécutent depuis ce dossier.

```bash
cd ateliers/a1-mongodb-docker
docker compose config --quiet
docker compose up -d
docker compose ps
```

Créer puis lire le document `T-101` dans la base `support` :

```bash
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin --quiet \
  --eval 'db.getSiblingDB("support").tickets.updateOne({code:"T-101"},{$set:{sujet:"Acces au portail"}},{upsert:true})'
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin --quiet \
  --eval 'db.getSiblingDB("support").tickets.findOne({code:"T-101"},{_id:0})'
```

Si MongoDB termine encore son initialisation, attendre quelques secondes et relancer la commande.

Vérifier la persistance en remplaçant le conteneur :

```bash
docker compose ps -q mongo
docker compose down
docker compose up -d
docker compose ps -q mongo
docker compose exec mongo mongosh -u root -p example --authenticationDatabase admin --quiet \
  --eval 'db.getSiblingDB("support").tickets.findOne({code:"T-101"},{_id:0})'
docker volume ls --filter name=mongo-data
```

Depuis un client sur l'hôte : `mongodb://root:example@127.0.0.1:27018/support?authSource=admin`. Depuis un autre service du même projet Compose : `mongodb://root:example@mongo:27017/support?authSource=admin` (nom du service, port interne).

## Résultats attendus

- `docker compose config --quiet` ne renvoie rien (configuration valide).
- `docker compose ps` montre le service `mongo` à l'état `running`, publié sur `127.0.0.1:27018`.
- Le premier `updateOne` indique `upsertedCount: 1` ; `findOne` renvoie `{ code: 'T-101', sujet: 'Acces au portail' }`.
- Après `down` puis `up -d`, l'identifiant du conteneur a changé mais `findOne` renvoie toujours `T-101` : les données vivent dans le volume nommé, pas dans le conteneur.

## Preuves

Exécution du 2026-11-18 : Docker Engine 29.2.0 (Docker Desktop 4.59, WSL 2 Debian), Docker Compose v5.0.2.

Démarrage :

```text
$ docker compose config --quiet
(aucune sortie, code 0)
$ docker compose ps
SERVICE   IMAGE     STATE     PORTS
mongo     mongo:7   running   127.0.0.1:27018->27017/tcp
```

Écriture puis lecture de `T-101` :

```text
{
  acknowledged: true,
  insertedId: ObjectId('6afd5f392f2e33dc3751edac'),
  matchedCount: 0,
  modifiedCount: 0,
  upsertedCount: 1
}
{ code: 'T-101', sujet: 'Acces au portail' }
```

Remplacement du conteneur par `docker compose down` puis `docker compose up -d` :

```text
# conteneur avant
21f69e9fe19b
# conteneur après
3de92fb12d8f
# lecture après remplacement
{ code: 'T-101', sujet: 'Acces au portail' }
$ docker volume ls --filter name=mongo-data
DRIVER    VOLUME NAME
local     a1-mongodb-docker_mongo-data
```

Conclusion : l'identifiant du conteneur a changé, et le document `T-101` est toujours lu. Les données sont dans le volume nommé `a1-mongodb-docker_mongo-data`, que `down` sans `-v` conserve.

## Nettoyage

```bash
docker compose down
```

Le volume nommé est conservé. Pour une remise à zéro volontaire, `docker compose down -v` supprime aussi les volumes déclarés dans ce projet, donc les données.
