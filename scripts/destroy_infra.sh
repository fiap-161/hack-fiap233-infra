#!/usr/bin/env bash
# destroy_infra.sh — Destrói toda a infraestrutura na ordem correta.
# Execute a partir da raiz do repositório hack-fiap233-infra.
# Ordem: 1) recursos no EKS (kubectl) 2) infra principal (Terraform) 3) bucket S3 do state (bootstrap).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HACKATHON_ROOT="$(cd "$INFRA_ROOT/.." && pwd)"
USERS_K8S="$HACKATHON_ROOT/hack-fiap233-users/k8s"
VIDEOS_K8S="$HACKATHON_ROOT/hack-fiap233-videos/k8s"

log() { echo "[destroy_infra] $*" >&2; }

cd "$INFRA_ROOT"

# 1. Remover workloads do EKS (para o destroy da infra principal conseguir apagar o cluster)
if command -v kubectl &>/dev/null; then
  if [[ -d "$USERS_K8S" ]]; then
    log "Removendo recursos Kubernetes (users)..."
    kubectl delete -f "$USERS_K8S/" --ignore-not-found --timeout=60s 2>/dev/null || true
  fi
  if [[ -d "$VIDEOS_K8S" ]]; then
    log "Removendo recursos Kubernetes (videos)..."
    kubectl delete -f "$VIDEOS_K8S/" --ignore-not-found --timeout=60s 2>/dev/null || true
  fi
else
  log "kubectl não encontrado; pulando remoção de recursos no EKS."
fi

# 2. Destruir infraestrutura principal (EKS, ECR, RDS, API Gateway, etc.)
BUCKET_NAME=""
if [[ -d bootstrap ]]; then
  BUCKET_NAME="$(cd bootstrap && terraform output -raw bucket_name 2>/dev/null || true)"
fi
if [[ -n "$BUCKET_NAME" ]]; then
  log "Inicializando backend e destruindo infraestrutura principal..."
  terraform init -reconfigure -input=false -backend-config="bucket=$BUCKET_NAME"
  terraform destroy -auto-approve -input=false
else
  log "Bucket do bootstrap não encontrado. Inicializando Terraform e destruindo..."
  terraform init -input=false
  terraform destroy -auto-approve -input=false
fi

# 3. Destruir o bucket S3 do state (bootstrap)
if [[ -d bootstrap ]]; then
  log "Destruindo bucket S3 do state (bootstrap)..."
  cd bootstrap
  terraform init -input=false
  terraform destroy -auto-approve -input=false
  cd ..
fi

log "Concluído. Todos os recursos foram destruídos."
