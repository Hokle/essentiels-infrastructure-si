terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      # Support : 3.6.1, refusée par OpenTofu (signature d'émetteur inconnu).
      # 3.9.0 = dernière 3.x signée par une clé reconnue (voir README de B1).
      version = "3.9.0"
    }
  }
}

provider "docker" {}
