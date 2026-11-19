# Entrées. Les valeurs locales vont dans terraform.tfvars (ignoré par Git) ;
# terraform.tfvars.example donne le modèle.

variable "db_name" {
  description = "Nom de la base de l'application."
  type        = string
  default     = "websolutions"
}

variable "db_user" {
  description = "Compte PostgreSQL de l'application."
  type        = string
  default     = "websolutions"
}

variable "db_password" {
  description = "Mot de passe du compte PostgreSQL (laboratoire)."
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Clé publique autorisée pour le compte infra de l'hôte web (utilisée par Ansible)."
  type        = string
}

variable "web_http_port" {
  description = "Port de l'hôte qui publie Nginx, sur la boucle locale."
  type        = number
  default     = 8085
}

variable "web_ssh_port" {
  description = "Port de l'hôte qui publie SSH vers l'hôte web, sur la boucle locale."
  type        = number
  default     = 2230
}
