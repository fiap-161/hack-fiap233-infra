#!/usr/bin/env bash
# setup_infra.sh — Bootstrap (S3 state) + provisionamento da infraestrutura Terraform.
# Execute a partir da raiz do repositório hack-fiap233-infra. Requer: terraform, AWS CLI configurado.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REGION="${AWS_REGION:-us-east-1}"

log() { echo "[setup_infra] $*" >&2; }

cd "$INFRA_ROOT"

# 1. Bootstrap: bucket S3 para remote state (idempotente; pode já existir)
if [[ -d bootstrap ]]; then
  log "Criando/atualizando bucket S3 para state..."
  cd bootstrap
  terraform init -input=false
  terraform apply -auto-approve -input=false
  cd ..
fi

# 2. Infraestrutura principal (usa o bucket criado no bootstrap)
BUCKET_NAME=""
if [[ -d bootstrap ]]; then
  BUCKET_NAME="$(cd bootstrap && terraform output -raw bucket_name 2>/dev/null || true)"
fi
log "Provisionando infraestrutura (EKS, ECR, RDS, API Gateway, etc.)..."
if [[ -n "$BUCKET_NAME" ]]; then
  terraform init -reconfigure -input=false -backend-config="bucket=$BUCKET_NAME"
else
  terraform init -input=false
fi
terraform apply -auto-approve -input=false

log "Concluído. Anote os outputs: terraform output"
