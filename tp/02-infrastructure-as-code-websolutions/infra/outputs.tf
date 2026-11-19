# Sorties utiles à l'équipe et aux outils suivants (Ansible, pipeline).

output "web_url" {
  description = "Adresse de l'application derrière Nginx."
  value       = "http://127.0.0.1:${var.web_http_port}"
}

output "ssh_target" {
  description = "Cible SSH de l'hôte web pour Ansible."
  value       = "infra@127.0.0.1:${var.web_ssh_port}"
}

output "network_name" {
  description = "Réseau sur lequel le pipeline déploie l'API."
  value       = docker_network.test.name
}

output "db_host" {
  description = "Nom de la base sur le réseau de test (pas de port publié)."
  value       = "db:5432"
}
