#!/usr/bin/env bash
# Exécute le DLC complet de la Partie A et enregistre chaque sortie dans evidence/
# Usage : ./scripts/run_partA.sh   (depuis la racine tp-iac-local/)
set -euo pipefail
mkdir -p evidence
log() { echo -e "\n\033[1;34m==> $*\033[0m"; }

log "1. terraform init"
terraform init -no-color 2>&1 | tee evidence/A1_init.txt

log "   (bonus) fmt + validate"
{ terraform fmt -check -recursive && echo "fmt: OK"; terraform validate -no-color; } 2>&1 | tee evidence/A1b_validate.txt

log "2. terraform plan"
terraform plan -no-color 2>&1 | tee evidence/A2_plan.txt

log "3. terraform apply -auto-approve"
terraform apply -auto-approve -no-color 2>&1 | tee evidence/A3_apply.txt

log "4. Validation"
sleep 5   # laisse Postgres démarrer
{
  echo "\$ docker ps --filter name=tp-"
  docker ps --filter name=tp- --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
  echo; echo "\$ curl -s http://localhost:8080/"
  curl -s http://localhost:8080/; echo
  echo; echo "\$ curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/"
  curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/
  echo; echo "\$ docker exec tp-db-postgres pg_isready -U devops_user -d devops_db"
  docker exec tp-db-postgres pg_isready -U devops_user -d devops_db
  echo; echo "\$ docker exec tp-db-postgres psql -U devops_user -d devops_db -c 'SELECT current_database(), current_user, version();'"
  docker exec tp-db-postgres psql -U devops_user -d devops_db -c 'SELECT current_database(), current_user, version();'
  echo; echo "\$ terraform output"
  terraform output -no-color
  echo; echo "\$ terraform state list"
  terraform state list
} 2>&1 | tee evidence/A4_validation.txt

echo
read -rp "Fais ta capture navigateur de http://localhost:8080/ puis Entrée pour détruire... "

log "5. terraform destroy -auto-approve"
terraform destroy -auto-approve -no-color 2>&1 | tee evidence/A5_destroy.txt
{
  echo "\$ docker ps -a --filter name=tp-"
  docker ps -a --filter name=tp- --format 'table {{.Names}}\t{{.Status}}'
  echo; echo "\$ terraform state list   (vide = rien n'est plus géré)"
  terraform state list
  echo "(fin)"
} 2>&1 | tee -a evidence/A5_destroy.txt

log "Terminé. Preuves dans evidence/"
