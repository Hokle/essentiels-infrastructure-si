# Environnement de test WebSolutions : un réseau, une base avec son volume
# et l'hôte qui portera le serveur web. L'API est déployée par le pipeline
# (dossier deploy/) sur ce même réseau.

resource "docker_network" "test" {
  name = "websolutions-test-net"
}

# --- Base de données -------------------------------------------------------

resource "docker_volume" "db" {
  name = "websolutions-db"
}

resource "docker_image" "postgres" {
  name         = "postgres:16-alpine"
  keep_locally = true
}

resource "docker_container" "db" {
  name    = "websolutions-db"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"
  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}"
  ]

  # Aucun port publié : la base n'est joignable que depuis le réseau de test.
  networks_advanced {
    name    = docker_network.test.name
    aliases = ["db"]
  }
  volumes {
    volume_name    = docker_volume.db.name
    container_path = "/var/lib/postgresql/data"
  }
  healthcheck {
    test     = ["CMD", "pg_isready", "-h", "127.0.0.1", "-U", var.db_user, "-d", var.db_name]
    interval = "3s"
    timeout  = "2s"
    retries  = 20
  }
  wait         = true
  wait_timeout = 90
}

# --- Hôte web ---------------------------------------------------------------
# Ubuntu 24.04 joignable en SSH par clé, avec un compte sudo « infra » :
# même image que la cible des ateliers B3 et B4. Ansible y installe Nginx.

resource "docker_image" "web_host" {
  name = "websolutions-web-host:24.04"
  build {
    context    = abspath("${path.module}/../../../ateliers/b3-nginx-puppet/cible")
    build_args = { SSH_PUBKEY = var.ssh_public_key }
  }
  keep_locally = true
}

resource "docker_container" "web" {
  name     = "websolutions-web"
  hostname = "websolutions-web"
  image    = docker_image.web_host.image_id
  restart  = "unless-stopped"

  networks_advanced {
    name    = docker_network.test.name
    aliases = ["web"]
  }
  # HTTP et SSH publiés sur la boucle locale seulement.
  ports {
    internal = 80
    external = var.web_http_port
    ip       = "127.0.0.1"
  }
  ports {
    internal = 22
    external = var.web_ssh_port
    ip       = "127.0.0.1"
  }
}
