# Essentiels de l'infrastructure du SI

Travaux pratiques du module : du service local à l'infrastructure automatisée (Docker, VM, réseau, stockage, Kubernetes, OpenTofu, Puppet, Ansible).

Chaque dossier contient les sources du scénario et un README qui précise les prérequis, les commandes, les résultats attendus, les preuves et le nettoyage.

## Ateliers

| Atelier | Sujet | Dossier | État |
| :--- | :--- | :--- | :--- |
| A1 | MongoDB avec Docker | [ateliers/a1-mongodb-docker](ateliers/a1-mongodb-docker/) | Fait |
| A2 | VM Linux et conteneur web | [ateliers/a2-vm-linux-conteneur-web](ateliers/a2-vm-linux-conteneur-web/) | À faire |
| A3 | Connecter une VM | [ateliers/a3-reseau-vm](ateliers/a3-reseau-vm/) | À faire |
| A4 | Stockage virtuel et montage d'un disque | [ateliers/a4-stockage-virtuel](ateliers/a4-stockage-virtuel/) | À faire |
| A5 | Nginx avec Minikube | [ateliers/a5-nginx-minikube](ateliers/a5-nginx-minikube/) | Fait |
| B1 | Nginx avec OpenTofu | [ateliers/b1-nginx-opentofu](ateliers/b1-nginx-opentofu/) | À faire |
| B2 | Catalogue Node.js, PostgreSQL et Redis | [ateliers/b2-catalogue-node-postgres-redis](ateliers/b2-catalogue-node-postgres-redis/) | À faire |
| B3 | Nginx avec Puppet | [ateliers/b3-nginx-puppet](ateliers/b3-nginx-puppet/) | À faire |
| B4 | Nginx avec Ansible | [ateliers/b4-nginx-ansible](ateliers/b4-nginx-ansible/) | À faire |

## Travaux pratiques

| TP | Sujet | Dossier | État |
| :--- | :--- | :--- | :--- |
| 01 | Docker et Minikube : image Node.js | [tp/01-docker-minikube-node](tp/01-docker-minikube-node/) | À faire |
| 02 | Infrastructure as Code pour WebSolutions | [tp/02-infrastructure-as-code-websolutions](tp/02-infrastructure-as-code-websolutions/) | À faire |
| 03 | OpenTofu avancé : DevSecOps | [tp/03-opentofu-avance/devsecops](tp/03-opentofu-avance/devsecops/) | À faire |
| 03 | OpenTofu avancé : supervision | [tp/03-opentofu-avance/supervision](tp/03-opentofu-avance/supervision/) | À faire |

## Données sensibles

Aucun secret réel n'est versionné. Les valeurs locales vont dans des fichiers ignorés (`.env`, `terraform.tfvars`) ; seuls les modèles (`.env.example`, `terraform.tfvars.example`) et `.terraform.lock.hcl` sont publiés.
