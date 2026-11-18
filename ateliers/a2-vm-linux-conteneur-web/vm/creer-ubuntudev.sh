#!/usr/bin/env bash
# Crée la VM UbuntuDev de l'atelier A2 et lance l'installation automatique d'Ubuntu Server 24.04.
# S'exécute depuis WSL et pilote VirtualBox (Windows) par VBoxManage.exe.
#
#   ISO=/mnt/c/Users/<moi>/Downloads/ubuntu-24.04.5-live-server-amd64.iso \
#   PASSWORD_FILE=<fichier hors dépôt contenant le mot de passe du compte infra> \
#   SSH_PUBKEY=~/.ssh/infra_si_lab.pub \
#   ./creer-ubuntudev.sh
set -euo pipefail

: "${ISO:?chemin vers ubuntu-24.04.x-live-server-amd64.iso}"
: "${PASSWORD_FILE:?fichier du mot de passe du compte infra}"
: "${SSH_PUBKEY:?clé publique SSH autorisée}"
VBOX="${VBOX:-/mnt/c/Program Files/Oracle/VirtualBox/VBoxManage.exe}"
VM=UbuntuDev
here=$(cd "$(dirname "$0")" && pwd)

vbox() { "$VBOX" "$@" | tr -d '\r'; }

# Modèle d'installation avec la clé publique insérée, déposé côté Windows pour VBoxManage.
stage=$(wslpath "$(cmd.exe /c echo %TEMP% 2>/dev/null | tr -d '\r')")/ubuntudev-user-data.tpl
sed "s|__SSH_AUTHORIZED_KEY__|$(cat "$SSH_PUBKEY")|" "$here/autoinstall-user-data.tpl" > "$stage"

vbox createvm --name "$VM" --ostype Ubuntu24_LTS_64 --register
# 2 vCPU, 2 Go, adaptateur 1 en NAT. Redirections limitées à la boucle locale de l'hôte :
# SSH (hôte 2222 -> invité 22) et web (hôte 8088 -> invité 8088, comme dans le support).
vbox modifyvm "$VM" --cpus 2 --memory 2048 --vram 16 --graphicscontroller vmsvga \
  --nic1 nat --natpf1 "ssh,tcp,127.0.0.1,2222,,22" --natpf1 "web,tcp,127.0.0.1,8088,,8088"

# Disque VDI dynamique (--variant Standard) de 20 Go sur un contrôleur SATA.
folder=$(vbox list systemproperties | sed -n 's/^Default machine folder: *//p')
disk="$folder\\$VM\\$VM.vdi"
vbox createmedium disk --filename "$disk" --size 20480 --format VDI --variant Standard
vbox storagectl "$VM" --name SATA --add sata --controller IntelAhci
vbox storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$disk"

vbox unattended install "$VM" \
  --iso="$(wslpath -w "$ISO")" \
  --user=infra --full-user-name=infra --password-file="$(wslpath -w "$PASSWORD_FILE")" \
  --hostname=ubuntudev.lab --locale=fr_FR --country=FR --time-zone=Europe/Paris \
  --script-template="$(wslpath -w "$stage")" \
  --start-vm=headless
rm -f "$stage"
