output "db_container_name" {
  description = "Nom du conteneur PostgreSQL"
  value       = docker_container.db_container.name
}

output "db_connection" {
  description = "Hôte:port de la base"
  value       = "localhost:${var.db_port_external}"
}

output "app_container_name" {
  description = "Nom du conteneur web"
  value       = docker_container.app_container.name
}

output "app_access_url" {
  description = "URL d'accès à l'application"
  value       = "http://localhost:${var.app_port_external}"
}
