# A2 · VM Linux et conteneur web

Objectif : créer une VM Ubuntu Server 24.04, lui attribuer des ressources et distinguer l'adresse de la VM de celle d'un conteneur Nginx.

> **État au 2026-11-18, 13:20 : vérification incomplète.** La VM est créée et Ubuntu Server 24.04.5 est installé. En revanche, le système installé ne termine pas son démarrage sous VirtualBox sur ce poste (voir [Résultat obtenu](#résultat-obtenu)). Étapes restant à valider : démarrage du système installé, `ip -br addr` et `ip route`, Docker Engine dans l'invité, conteneur `web-vm`.

## Prérequis

- VirtualBox 7.2 (installé ici par `winget install --exact --id Oracle.VirtualBox`).
- ISO Ubuntu Server 24.04 LTS AMD64 (ici `ubuntu-24.04.5-live-server-amd64.iso`, SHA256 vérifié contre `https://releases.ubuntu.com/24.04/SHA256SUMS`).
- Pour le script : WSL, avec `VBoxManage.exe` accessible depuis WSL.

## Réglages de la VM

| Réglage | Valeur |
| :--- | :--- |
| Nom | `UbuntuDev` |
| Système invité | `Ubuntu24_LTS_64` (Ubuntu 24.04 LTS, 64 bits) |
| Processeurs | 2 |
| Mémoire | 2 Go |
| Disque | VDI dynamique de 20 Go, contrôleur SATA |
| Carte réseau 1 | NAT |
| Redirection `ssh` | `127.0.0.1:2222` → invité `22` |
| Redirection `web` | `127.0.0.1:8088` → invité `8088` |
| Compte | `infra`, mot de passe hors dépôt ; clé SSH publique autorisée à l'installation |

Les redirections n'écoutent que sur la boucle locale de l'hôte. Le disque virtuel reste sur le poste et n'est pas versionné.

## Procédure de reproduction

Le support crée la VM à la main dans l'interface de VirtualBox. Ici, la même VM est créée par script, ce qui permet de rejouer exactement les mêmes réglages :

- [`vm/creer-ubuntudev.sh`](vm/creer-ubuntudev.sh) : `VBoxManage createvm`, `modifyvm` (CPU, mémoire, NAT, redirections), `createmedium` (VDI dynamique), `storagectl` et `storageattach`, puis `unattended install`.
- [`vm/autoinstall-user-data.tpl`](vm/autoinstall-user-data.tpl) : modèle d'installation automatique de VirtualBox, auquel j'ai ajouté le clavier français et le serveur OpenSSH avec une clé autorisée. Sans cet ajout, le modèle d'origine n'installe pas OpenSSH.

```bash
ISO=/mnt/c/Users/<moi>/Downloads/ubuntu-24.04.5-live-server-amd64.iso \
PASSWORD_FILE=<fichier hors dépôt> \
SSH_PUBKEY=~/.ssh/<clé>.pub \
./vm/creer-ubuntudev.sh
```

Commandes prévues dans l'invité, une fois la VM démarrée (d'après le support) :

```bash
ip -br addr
ip route
sudo docker run -d --name web-vm -p 8088:80 nginx:1.28-alpine
sudo docker ps
sudo docker exec web-vm nginx -t
curl -I http://127.0.0.1:8088
sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-vm
```

## Résultats attendus

- La VM obtient une adresse NAT (en général `10.0.2.15/24` sur `enp0s3`, route par défaut via `10.0.2.2`).
- Le conteneur Nginx a une adresse Docker distincte (en général `172.17.0.x`), joignable par la publication du port `8088` : depuis la VM sur `127.0.0.1:8088`, et depuis l'hôte grâce à la redirection NAT.

## Résultat obtenu

Création et installation :

```text
Virtual machine 'UbuntuDev' is created and registered.
Medium created. UUID: be3d8529-0eed-4d64-baee-de10a57c4cc3
                  detectedOSTypeId = Ubuntu24_64
                 detectedOSVersion = 24.04.5 LTS "Noble Numbat"
                  detectedOSFlavor = Ubuntu-Server
VBoxManage.exe: info: VM 'UbuntuDev' (...) has been successfully started.
```

L'installateur (subiquity) s'est exécuté jusqu'au bout : extraction, configuration du clavier, installation du noyau. La VM a ensuite redémarré sur son disque.

Démarrage du système installé : **échec**. Le poste fait tourner WSL 2 et Docker Desktop, donc Hyper-V est actif, et VirtualBox ne peut pas utiliser AMD-V directement. Il passe par l'API de Windows (mode NEM), comme l'indique `VBox.log` :

```text
HM: HMR3Init: Attempting fall back to NEM: AMD-V is not available
TM: Host/VM is not suitable for using TSC mode 'RealTSCOffset', request to change TSC mode ignored
```

Essais réalisés sur l'interface de paravirtualisation et le nombre de processeurs, avec une capture de la console à chaque fois :

| Paravirtualisation | vCPU | Résultat |
| :--- | :---: | :--- |
| `default` (KVM pour Linux) | 2 | bloqué sur `Begin: Loading essential drivers ...`, y compris après un reset |
| `none` | 2 | même blocage |
| `none` | 1 | panique du noyau : `IO-APIC + timer doesn't work!` |
| `hyperv` | 2 | le noyau va plus loin (disque `sda1 sda2` détecté) puis se fige ; SSH accepte la connexion TCP mais ne répond pas (`Connection timed out during banner exchange`) |

Conclusion provisoire : l'horloge de l'invité ne fonctionne pas correctement sous VirtualBox en mode NEM sur ce poste. La VM reste réglée en `hyperv`, avec 2 vCPU et un contrôleur SATA réduit à 2 ports.

## Nettoyage

Une fois les ateliers A3 et A4 terminés (ils réutilisent cette VM) :

```bash
"/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" controlvm UbuntuDev poweroff
"/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe" unregistervm UbuntuDev --delete
```
