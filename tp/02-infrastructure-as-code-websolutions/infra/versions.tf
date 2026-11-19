terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
      # 3.9.0 plutôt que 3.6.1 : OpenTofu refuse la signature des versions <= 3.6.2 sur ce poste (voir B1).
      version = "3.9.0"
    }
  }
}

provider "docker" {}
