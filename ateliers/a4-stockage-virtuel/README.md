# A4 · Attacher et monter un disque

Objectif : ajouter un disque VDI, le partitionner, le formater, le monter et retrouver un fichier témoin après remontage.

> **État au 2026-11-18 : préparé, non exécuté.** Cet atelier réutilise la VM `UbuntuDev` de A2, dont le système installé ne démarre pas sur ce poste (VirtualBox en mode NEM sous Hyper-V, voir [A2](../a2-vm-linux-conteneur-web/README.md#résultat-obtenu)). La procédure est prête. Étape restante : l'exécuter dans la VM démarrée et relever les sorties réelles.

## Prérequis

- La VM `UbuntuDev` de A2, éteinte pour l'ajout du disque.
- Contrôleur `SATA` de la VM (créé par le script de A2) : port 0 pour le disque système. Le port 1 doit être libre, à vérifier avant le rattachement avec `"$VBOX" showvminfo UbuntuDev | grep SATA`.

## Commandes

Sur l'hôte, VM éteinte : création d'un VDI dynamique de 1 Go et rattachement au port SATA 1.

```bash
VBOX="/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
"$VBOX" createmedium disk --filename 'C:\Users\<moi>\VirtualBox VMs\UbuntuDev\data.vdi' --size 1024 --format VDI --variant Standard
"$VBOX" storageattach UbuntuDev --storagectl SATA --port 1 --device 0 --type hdd --medium 'C:\Users\<moi>\VirtualBox VMs\UbuntuDev\data.vdi'
"$VBOX" startvm UbuntuDev --type headless
```

Dans la VM : repérer le nouveau disque (en général `sdb`, sans partition), puis le partitionner en GPT avec une seule partition.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
sudo fdisk /dev/sdb        # g (table GPT), n (nouvelle partition, valeurs par défaut), w (écrire)
lsblk /dev/sdb
```

Formatage, montage et fichier témoin :

```bash
sudo mkfs.ext4 -L data /dev/sdb1
sudo mkdir -p /mnt/data
sudo mount /dev/sdb1 /mnt/data
echo "temoin A4 $(date -Is)" | sudo tee /mnt/data/temoin.txt
df -h /mnt/data
```

Démontage et remontage, pour prouver que la donnée est sur le disque et non en mémoire :

```bash
sudo umount /mnt/data
ls /mnt/data               # vide
sudo mount /dev/sdb1 /mnt/data
cat /mnt/data/temoin.txt
```

Montage permanent, par UUID plutôt que par nom de périphérique (le nom `sdb` peut changer d'un démarrage à l'autre) :

```bash
UUID=$(sudo blkid -s UUID -o value /dev/sdb1)
echo "UUID=$UUID /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo umount /mnt/data
sudo findmnt --verify
sudo mount -a
findmnt /mnt/data
sudo reboot                 # puis : findmnt /mnt/data && cat /mnt/data/temoin.txt
```

`nofail` évite que la VM reste bloquée au démarrage si le disque est absent. `findmnt --verify` contrôle `/etc/fstab` avant de redémarrer.

## Résultats attendus

- `lsblk` montre `sdb` (1G) puis `sdb1`, en `ext4` avec le label `data`.
- `df -h /mnt/data` montre le volume monté (environ 1 Go).
- `temoin.txt` disparaît de `/mnt/data` après `umount` et réapparaît au remontage, puis après redémarrage.

## Preuves

Aucune sortie réelle : l'atelier n'a pas pu être exécuté (voir l'état en tête).

## Nettoyage

```bash
# Dans la VM : retirer la ligne UUID=… de /etc/fstab, puis
sudo umount /mnt/data
# Sur l'hôte, VM éteinte
"$VBOX" storageattach UbuntuDev --storagectl SATA --port 1 --device 0 --medium none
"$VBOX" closemedium disk 'C:\Users\<moi>\VirtualBox VMs\UbuntuDev\data.vdi' --delete
```
