# A5 · Déployer Nginx avec Minikube

Objectif : déployer Nginx dans Minikube, l'exposer par un Service et observer le remplacement d'un Pod.

## Prérequis

- Moteur Docker démarré en mode conteneurs Linux (pilote `docker` de Minikube).
- Minikube installé. `minikube kubectl --` télécharge un `kubectl` de la même version que le cluster : pas besoin d'en installer un séparément.
- Port `8090` libre sur l'hôte pour le `port-forward`.

## Fichiers

| Fichier | Rôle |
| :--- | :--- |
| `deployment.yaml` | Deployment `nginx` : 1 réplique de `nginx:1.28-alpine`, Pods étiquetés `app=nginx`. |
| `service.yaml` | Service `ClusterIP` `nginx` : point d'accès stable, port 80, vers les Pods `app=nginx`. |

Le support crée ces objets avec `kubectl create deployment` puis `kubectl expose`. Ici, ils sont décrits dans des manifestes versionnés, pour pouvoir les relire et les rejouer à l'identique. Ce sont les objets que génèrent ces commandes (`--dry-run=client -o yaml`), débarrassés des champs vides.

## Commandes

Depuis ce dossier :

```bash
minikube start -p infra-si --driver=docker
minikube -p infra-si kubectl -- get nodes
minikube -p infra-si kubectl -- apply -f deployment.yaml -f service.yaml
minikube -p infra-si kubectl -- rollout status deployment/nginx --timeout=120s
minikube -p infra-si kubectl -- get pods,services
```

Tester depuis l'hôte : laisser cette commande active dans un terminal, puis ouvrir http://127.0.0.1:8090 (ou `curl -sI http://127.0.0.1:8090` dans un autre terminal).

```bash
minikube -p infra-si kubectl -- port-forward service/nginx 8090:80
```

Observer le remplacement d'un Pod (après avoir arrêté le `port-forward` avec Ctrl+C) :

```bash
minikube -p infra-si kubectl -- get pods
minikube -p infra-si kubectl -- delete pod NOM_DU_POD
minikube -p infra-si kubectl -- get pods
```

## Résultats attendus

- Le nœud `infra-si` est `Ready`, et `rollout status` se termine par `successfully rolled out`.
- `get pods,services` montre un Pod `nginx-…` en `1/1 Running` et un Service `nginx` de type `ClusterIP` sur `80/TCP`.
- Le `port-forward` permet d'obtenir `HTTP/1.1 200 OK` et la page « Welcome to nginx! ».
- Après `delete pod`, un Pod portant un **autre nom** apparaît aussitôt : le ReplicaSet du Deployment rétablit la réplique demandée. Le Service, qui sélectionne les Pods par étiquette et non par nom, sert le nouveau Pod sans modification.

## Preuves

Exécution du 2026-11-18 : Minikube v1.39.0, pilote `docker`, Kubernetes v1.37.0 (runtime containerd 2.3.4).

Déploiement :

```text
$ kubectl get nodes
NAME       STATUS   ROLES           AGE   VERSION
infra-si   Ready    control-plane   28s   v1.37.0
$ kubectl apply -f deployment.yaml -f service.yaml
deployment.apps/nginx created
service/nginx created
$ kubectl rollout status deployment/nginx --timeout=120s
Waiting for deployment "nginx" rollout to finish: 0 of 1 updated replicas are available...
deployment "nginx" successfully rolled out
$ kubectl get pods,services
NAME                         READY   STATUS    RESTARTS   AGE
pod/nginx-7455c48846-mc564   1/1     Running   0          5s

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   31s
service/nginx        ClusterIP   10.108.247.107   <none>        80/TCP    5s
```

Accès depuis l'hôte par `port-forward service/nginx 8090:80` :

```text
$ curl -sI http://127.0.0.1:8090
HTTP/1.1 200 OK
Server: nginx/1.28.3
$ curl -s http://127.0.0.1:8090 | grep -o "<title>.*</title>"
<title>Welcome to nginx!</title>
```

Remplacement du Pod :

```text
$ kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7455c48846-mc564   1/1     Running   0          23s
$ kubectl delete pod nginx-7455c48846-mc564
pod "nginx-7455c48846-mc564" deleted from default namespace
$ kubectl get pods
NAME                     READY   STATUS    RESTARTS   AGE
nginx-7455c48846-8wc48   1/1     Running   0          0s
$ kubectl get deployment nginx
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   1/1     1            1           25s
$ curl -sI http://127.0.0.1:8090   # port-forward relancé, nouveau Pod
HTTP/1.1 200 OK
```

Conclusion : le Pod `mc564` supprimé est remplacé par `8wc48`, issu du même ReplicaSet (`7455c48846`). Le Deployment revient à `1/1`, et le Service répond de nouveau sans avoir été modifié.

## Nettoyage

Arrêter le `port-forward` s'il est encore actif, puis supprimer le profil de laboratoire :

```bash
minikube delete -p infra-si
```
