# TP — Infrastructure as Code (Terraform + Docker) & CI/CD

**Étudiant :** Youssef Bettaieb — INSAT, Réseaux et Télécommunications
**Environnement :** Windows + WSL2 (Ubuntu), Docker, Terraform, Git

## Sommaire
- [Partie A — IaC locale](#partie-a--iac-locale)
  - [A.0 Prérequis](#a0-prérequis)
  - [A.1 Structure du projet](#a1-structure-du-projet)
  - [A.2 Conteneurisation de l'application](#a2-conteneurisation-de-lapplication-dockerfile_app)
  - [A.3 Code Terraform](#a3-code-terraform)
  - [A.4 Cycle de vie du déploiement (DLC)](#a4-cycle-de-vie-du-déploiement-dlc)
- [Partie B — Pipeline CI/CD](#partie-b--pipeline-cicd)
- [Questions d'approfondissement](#questions-dapprofondissement)

---

# Partie A — IaC locale

**Objectif :** décrire en Terraform une infra composée d'une base PostgreSQL et d'une app web Nginx, puis dérouler le cycle Init → Plan → Apply → Validation → Destroy.

```
          terraform (provider kreuzwerker/docker)
                        │  unix:///var/run/docker.sock
        ┌───────────────┴───────────────┐
  tp-db-postgres                   tp-app-web
  postgres:latest                  tp-web-app:latest (Dockerfile_app)
  5432 → localhost:5432            80 → localhost:8080
```

## A.0 Prérequis

Vérification des outils dans WSL :

```bash
./scripts/check_prereqs.sh
```

```text
<!-- coller evidence/A0_prereqs.txt -->
```

## A.1 Structure du projet

```bash
tree -a -I '.git|.terraform' .
```

```text
<!-- coller la sortie de tree -->
```

| Fichier | Rôle |
|---|---|
| `main.tf` | Provider Docker + ressources (images et conteneurs) |
| `variables.tf` | Paramètres : credentials DB, ports |
| `outputs.tf` | Infos affichées après `apply` (URL, noms des conteneurs) |
| `Dockerfile_app` | Image Nginx/Alpine de l'application |
| `.gitignore` | Exclut le state, `.terraform/` et les `.tfvars` |

## A.2 Conteneurisation de l'application (`Dockerfile_app`)

```dockerfile
FROM alpine:latest

RUN apk add --no-cache nginx \
 && mkdir -p /run/nginx /var/www/app \
 && echo "<h1>Application Deployed via Terraform IaC!</h1>" > /var/www/app/index.html \
 && printf 'server {\n    listen 80 default_server;\n    listen [::]:80 default_server;\n    root /var/www/app;\n    index index.html;\n    location / {\n        try_files $uri $uri/ =404;\n    }\n}\n' > /etc/nginx/http.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Points clés :
- `alpine:latest` + `apk add --no-cache` : image légère, sans cache apk.
- Le `default.conf` livré avec Nginx sur Alpine renvoie **404** sur `/`. On le remplace par un vhost qui sert `/var/www/app`.
- `/run/nginx` : répertoire du fichier PID.
- `daemon off;` : Nginx reste au premier plan, sinon le conteneur s'arrête tout de suite.

## A.3 Code Terraform

### `variables.tf`

```hcl
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

variable "app_port_external" {
  description = "Port hôte mappé sur le 80 du conteneur Nginx"
  type        = number
  default     = 8080
}
```

`sensitive = true` masque le mot de passe dans le `plan` et l'`apply`.

### `main.tf`

```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    docker = { source = "kreuzwerker/docker", version = "~> 3.0" }
  }
}

provider "docker" {}

resource "docker_image" "postgres_image" {
  name         = "postgres:latest"
  keep_locally = true
}

resource "docker_container" "db_container" {
  name  = "tp-db-postgres"
  image = docker_image.postgres_image.image_id
  ports {
    internal = 5432
    external = var.db_port_external
  }
  env = [
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_DB=${var.db_name}",
  ]
}

resource "docker_image" "app_image" {
  name = "tp-web-app:latest"
  build {
    context    = path.module
    dockerfile = "Dockerfile_app"
  }
  triggers = {
    dockerfile_sha = filesha1("${path.module}/Dockerfile_app")
  }
}

resource "docker_container" "app_container" {
  name       = "tp-app-web"
  image      = docker_image.app_image.image_id
  depends_on = [docker_container.db_container]
  ports {
    internal = 80
    external = var.app_port_external
  }
}
```

Choix techniques :
- **`image_id` au lieu de `.latest`** : l'attribut `latest` utilisé dans l'énoncé a été supprimé dans le provider Docker v3. `image_id` est l'attribut correct.
- **`triggers` sur le SHA du Dockerfile** : si le Dockerfile change, Terraform reconstruit l'image et recrée le conteneur.
- **`depends_on`** : la DB est créée avant l'application (dépendance explicite, sans référence directe entre les deux).

### `outputs.tf`

```hcl
output "db_container_name"  { value = docker_container.db_container.name }
output "db_connection"      { value = "localhost:${var.db_port_external}" }
output "app_container_name" { value = docker_container.app_container.name }
output "app_access_url"     { value = "http://localhost:${var.app_port_external}" }
```

## A.4 Cycle de vie du déploiement (DLC)

Tout le cycle est scripté dans `scripts/run_partA.sh` ; chaque sortie est enregistrée dans `evidence/`.

### 1. Initialisation — `terraform init`
Télécharge le provider `kreuzwerker/docker`, crée `.terraform/` et le lock file `.terraform.lock.hcl`.

```bash
terraform init
terraform fmt -check && terraform validate
```
```text
<!-- coller evidence/A1_init.txt (lignes clés) + evidence/A1b_validate.txt -->
```

### 2. Planification — `terraform plan`
Compare le code avec le state (vide) et annonce les actions : **4 ressources à créer**.

```bash
terraform plan
```
```text
<!-- coller evidence/A2_plan.txt (garder la fin : "Plan: 4 to add, 0 to change, 0 to destroy.") -->
```

### 3. Application — `terraform apply -auto-approve`

```bash
terraform apply -auto-approve
```
```text
<!-- coller evidence/A3_apply.txt (lignes "Creation complete", "Apply complete! Resources: 4 added" et les Outputs) -->
```

### 4. Validation

```bash
docker ps --filter name=tp-
curl -s http://localhost:8080/
docker exec tp-db-postgres pg_isready -U devops_user -d devops_db
docker exec tp-db-postgres psql -U devops_user -d devops_db -c 'SELECT current_database(), current_user;'
terraform output
terraform state list
```
```text
<!-- coller evidence/A4_validation.txt -->
```

Capture navigateur de `http://localhost:8080/` :

![App déployée](evidence/A4_browser.png)

### 5. Destruction — `terraform destroy -auto-approve`

```bash
terraform destroy -auto-approve
docker ps -a --filter name=tp-
terraform state list
```
```text
<!-- coller evidence/A5_destroy.txt ("Destroy complete! Resources: 4 destroyed." + docker ps vide + state vide) -->
```

**Constat :** après le `destroy`, les deux conteneurs n'existent plus et le state ne référence plus aucune ressource. L'image `postgres:latest` reste en cache local car `keep_locally = true`.

### Difficultés rencontrées / corrections par rapport à l'énoncé
| Problème | Cause | Correction |
|---|---|---|
| `Unsupported attribute "latest"` | attribut retiré dans le provider docker v3 | `docker_image.x.image_id` |
| Page Nginx en 404 | le `default.conf` d'Alpine fait `return 404` | vhost personnalisé dans le Dockerfile |
| <!-- autre souci rencontré --> | | |

---

# Partie B — Pipeline CI/CD

*(à compléter)*

---

# Questions d'approfondissement

*(à compléter après la Partie B)*
