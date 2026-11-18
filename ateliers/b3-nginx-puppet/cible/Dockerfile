# Cible de remplacement pour B3 (Puppet) et B4 (Ansible) quand la VM UbuntuDev n'est pas disponible.
# Ubuntu 24.04 comme la VM du support, avec un compte sudo `infra`, OpenSSH et Python 3.
# Pas de systemd dans le conteneur : les services passent par les scripts /etc/init.d.
FROM ubuntu:24.04

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openssh-server python3 sudo curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
 && useradd -m -s /bin/bash infra \
 && usermod -p '*' infra \
 && echo 'infra ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/infra \
 && chmod 440 /etc/sudoers.d/infra

# Clé publique autorisée, passée à la construction : --build-arg SSH_PUBKEY="$(cat ~/.ssh/<clé>.pub)"
ARG SSH_PUBKEY
RUN install -d -m 700 -o infra -g infra /home/infra/.ssh \
 && echo "$SSH_PUBKEY" > /home/infra/.ssh/authorized_keys \
 && chown infra:infra /home/infra/.ssh/authorized_keys \
 && chmod 600 /home/infra/.ssh/authorized_keys

EXPOSE 22 80
CMD ["/usr/sbin/sshd", "-D", "-e"]
