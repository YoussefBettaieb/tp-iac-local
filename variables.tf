# --- Base de données PostgreSQL ---
variable "db_name" {
  description = "Nom de la base PostgreSQL"
  type        = string
  default     = "devops_db"
}

variable "db_user" {
  description = "Utilisateur PostgreSQL"
  type        = string
  default     = "devops_user"
}

variable "db_password" {
  description = "Mot de passe PostgreSQL (TP uniquement, pas pour la prod)"
  type        = string
  default     = "strongpassword123"
  sensitive   = true
}

variable "db_port_external" {
  description = "Port hôte mappé sur le 5432 du conteneur"
  type        = number
  default     = 5432
}

# --- Application web ---
variable "app_port_external" {
  description = "Port hôte mappé sur le 80 du conteneur Nginx"
  type        = number
  default     = 8080
}
