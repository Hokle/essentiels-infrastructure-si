# A3 · Connecter une VM

Objectif : identifier les deux interfaces (NAT et réseau privé hôte), observer la route par défaut et prouver chaque flux par un test.

> **État au 2026-11-18 : préparé, non exécuté.** Cet atelier réutilise la VM `UbuntuDev` de A2, dont le système installé ne démarre pas sur ce poste (VirtualBox en mode NEM sous Hyper-V, voir [A2](../a2-vm-linux-conteneur-web/README.md#résultat-obtenu)). La configuration réseau et la procédure sont prêtes. Étape restante : l'appliquer dans la VM démarrée et relever les sorties réelles.

## Prérequis

- La VM `UbuntuDev` de A2, éteinte pour l'ajout de la carte.
- Un réseau privé hôte VirtualBox (ici `VirtualBox Host-Only Ethernet Adapter`, hôte en `192.168.56.1/24`, sans DHCP).

## Plan d'adressage

| Interface | Réseau VirtualBox | Adresse | Rôle |
| :--- | :--- | :--- | :--- |
| `enp0s3` | NAT | `10.0.2.15/24` (DHCP), passerelle `10.0.2.2` | sortie Internet, route par défaut |
| `enp0s8` | Réseau privé hôte | `192.168.56.20/24`, fixe | dialogue direct hôte ⇄ VM |

L'adresse fixe est hors de toute plage DHCP. Aucune passerelle n'est déclarée sur `enp0s8` : la route par défaut reste sur le NAT.

## Commandes

Sur l'hôte, VM éteinte, ajout de la seconde carte :

```bash
VBOX="/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
"$VBOX" list hostonlyifs
"$VBOX" modifyvm UbuntuDev --nic2 hostonly --hostonlyadapter2 "VirtualBox Host-Only Ethernet Adapter"
"$VBOX" startvm UbuntuDev --type headless
```

Dans la VM, état initial puis adresse fixe avec [`60-lab.yaml`](60-lab.yaml) :

```bash
ip -br link
ip -br addr
ip route
sudo install -m 600 60-lab.yaml /etc/netplan/60-lab.yaml
sudo netplan generate
sudo netplan try          # retour arrière automatique sans confirmation sous 120 s
ip -br addr show enp0s8
ip route
```

Tests de chaque flux :

```bash
# Depuis la VM : sortie par le NAT
ping -c 2 10.0.2.2
ping -c 2 1.1.1.1
getent hosts ubuntu.com

# Depuis la VM : vers l'hôte par le réseau privé
ping -c 2 192.168.56.1

# Depuis l'hôte (Windows) : vers la VM par le réseau privé, sans redirection de port
ping -n 2 192.168.56.20
ssh infra@192.168.56.20
curl -I http://192.168.56.20:8088      # conteneur web-vm de A2
```

## Résultats attendus

- `ip -br addr` montre `enp0s3` en `10.0.2.15/24` et `enp0s8` en `192.168.56.20/24`.
- `ip route` garde une seule route par défaut, `default via 10.0.2.2 dev enp0s3`, et ajoute `192.168.56.0/24 dev enp0s8`.
- L'hôte joint la VM directement en `192.168.56.20` (SSH, HTTP), sans passer par les redirections NAT `127.0.0.1:2222` et `127.0.0.1:8088` de A2.
- La configuration survit au redémarrage (`sudo reboot`, puis `ip -br addr`).

## Preuves

Aucune sortie réelle : l'atelier n'a pas pu être exécuté (voir l'état en tête). Seul `60-lab.yaml` a été contrôlé, en YAML valide.

Point de vigilance relevé en préparant : le réseau privé hôte de VirtualBox n'est joignable que depuis Windows. WSL 2 tourne ici en mode NAT (`172.21.x`), donc les tests côté hôte se font depuis PowerShell, pas depuis WSL.

## Nettoyage

```bash
sudo rm /etc/netplan/60-lab.yaml && sudo netplan apply
"$VBOX" modifyvm UbuntuDev --nic2 none      # VM éteinte
```
