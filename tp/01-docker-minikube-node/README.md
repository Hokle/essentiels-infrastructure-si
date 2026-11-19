# TP 01 · Docker et Minikube

Objectif : construire une image Node.js et obtenir le même résultat HTTP sous Docker puis dans Kubernetes.

## Contenu

| Fichier | Rôle |
| :--- | :--- |
| [`server.js`](server.js) | serveur HTTP Node.js (module `node:http` intégré), répond sur le port 3000 |
| [`Dockerfile`](Dockerfile) | image `node:24-alpine`, exécution sous l'utilisateur `node`, port 3000 |
| [`.dockerignore`](.dockerignore) | n'envoie au moteur que `Dockerfile` et `server.js` |
| [`deployment.yaml`](deployment.yaml) | Deployment `hello-node` (1 réplique, sonde de disponibilité sur `/`) et Service `NodePort` 8080 → 3000, nœud 30007 |

## Prérequis

- Docker (ici Docker Desktop avec l'intégration WSL 2, moteur 29.2.0).
- Minikube (ici v1.39.0), profil dédié `intro-docker`, pilote `docker`.
- Node.js n'est pas nécessaire sur le poste : il est fourni par l'image.

## Commandes

Depuis ce dossier.

Docker :

```bash
docker build -t hello-node:1.0 .
docker run -d --name hello-node -p 127.0.0.1:8080:3000 hello-node:1.0
docker ps --filter name=hello-node
curl http://127.0.0.1:8080
docker rm -f hello-node
```

Kubernetes avec Minikube :

```bash
minikube start -p intro-docker --driver=docker
minikube -p intro-docker image load hello-node:1.0
minikube -p intro-docker image ls
minikube -p intro-docker kubectl -- apply -f deployment.yaml
minikube -p intro-docker kubectl -- rollout status deployment/hello-node
minikube -p intro-docker kubectl -- get pods,services
minikube -p intro-docker service hello-node --url     # garder le terminal ouvert
minikube -p intro-docker kubectl -- port-forward service/hello-node 8080:8080
```

## Résultats attendus

- Le conteneur Docker et le Pod renvoient le même message : `Hello, Docker and Minikube from Node.js!`.
- Le Pod est `1/1 Running` et prêt (`ready=true`) ; le Service expose `8080:30007/TCP`.

## Preuves

Obtenues le 2026-11-19 entre 08:56 et 09:00.

Docker :

```text
hello-node:1.0 074e6462ff15 244MB
NAMES        IMAGE            STATUS                  PORTS
hello-node   hello-node:1.0   Up Less than a second   127.0.0.1:8080->3000/tcp
200 text/plain; charset=utf-8 | Hello, Docker and Minikube from Node.js!
uid=1000(node) gid=1000(node) groups=1000(node)      # docker exec hello-node id
v24.22.3                                              # docker exec hello-node node --version
```

Après `docker rm -f hello-node`, l'image `074e6462ff15` reste disponible.

Minikube :

```text
docker.io/library/hello-node:1.0                      # image ls, après image load
deployment "hello-node" successfully rolled out
NAME                              READY   STATUS    RESTARTS   AGE   IP           NODE
pod/hello-node-7dd869979d-5g8v6   1/1     Running   0          12s   10.244.0.3   intro-docker
NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/hello-node   NodePort    10.111.153.222   <none>        8080:30007/TCP   12s
```

Accès au service :

```text
$ minikube -p intro-docker service hello-node --url
http://127.0.0.1:44777
! Because you are using a Docker driver on linux, the terminal needs to be open to run it.
200 Hello, Docker and Minikube from Node.js!          # via http://127.0.0.1:44777
200 Hello, Docker and Minikube from Node.js!          # via port-forward, http://127.0.0.1:8080
```

L'accès direct `http://192.168.58.2:30007` (IP du nœud, `minikube ip`) échoue par dépassement de délai depuis WSL : le nœud vit dans le réseau du moteur Docker Desktop, que la distribution WSL ne joint pas directement. C'est le cas prévu par le support, d'où le tunnel de `minikube service` ou le `port-forward`.

État du Pod et du Service :

```text
hello-node-7dd869979d-5g8v6 ready=true image=hello-node:1.0
port=8080 targetPort=3000 nodePort=30007
```

Cycle de vie : suppression manuelle du Pod, le Deployment en recrée un aussitôt.

```text
pod "hello-node-7dd869979d-5g8v6" deleted from default namespace
hello-node-7dd869979d-5g8v6   1/1   Terminating   0     72s
hello-node-7dd869979d-8bzfz   1/1   Running       0     2s
```

## Analyse

1. **Pourquoi Node.js n'a pas besoin d'être installé sur le poste.** Le moteur d'exécution fait partie de l'image : `FROM node:24-alpine` apporte Node.js 24 et ses bibliothèques. Le conteneur tourne avec sa propre version (`v24.22.3`), indépendante de ce qui est installé ou non sur l'hôte. Kubernetes exécute la même image, donc le même Node.js.
2. **Ce qui rend l'application accessible.** Dans les deux cas, l'application écoute sur `0.0.0.0:3000` dans le conteneur.
   - Docker : la publication `-p 127.0.0.1:8080:3000` relie le port 8080 de l'hôte, en boucle locale seulement, au port 3000 du conteneur.
   - Kubernetes : le Service sélectionne les Pods `app: hello-node` et transmet son port 8080 au port 3000 du Pod. Le `NodePort` 30007 ouvre le port sur le nœud. Depuis le poste, l'accès passe par le tunnel de `minikube service` ou par `kubectl port-forward`.
3. **Cycle de vie.** Un conteneur lancé par `docker run` vit tant qu'on ne l'arrête pas ; s'il s'arrête ou est supprimé, rien ne le recrée (sauf politique de redémarrage). Un Pod géré par un Deployment est jetable : le Deployment maintient le nombre de répliques voulu et recrée un Pod supprimé (preuve ci-dessus, nouveau nom `…-8bzfz`, nouvelle IP). Le Service suit les nouveaux Pods par leurs étiquettes, donc l'adresse d'accès ne change pas. La sonde de disponibilité retient le trafic tant que `/` ne répond pas.
4. **Relevés.** Pod `1/1`, `ready=true` ; Service `NodePort`, port 8080 → `targetPort` 3000, `nodePort` 30007 ; message HTTP `Hello, Docker and Minikube from Node.js!`.

`image load` est indispensable : le cluster Minikube a son propre moteur et ne voit pas les images de Docker Desktop. Avec `imagePullPolicy: IfNotPresent`, Kubernetes utilise l'image chargée au lieu d'aller la chercher sur un registre où elle n'existe pas.

## Nettoyage

Arrêter le tunnel ou le `port-forward` avec Ctrl+C, puis :

```bash
minikube -p intro-docker kubectl -- delete -f deployment.yaml
minikube delete -p intro-docker
docker image rm hello-node:1.0
```
