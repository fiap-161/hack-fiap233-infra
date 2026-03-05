#!/usr/bin/env bash
# deploy_services.sh — Configura kubectl, faz login no ECR, build/push das imagens, atualiza manifests e aplica no EKS.
# Execute a partir da raiz do repositório hack-fiap233-infra.
# Espera os repositórios hack-fiap233-users e hack-fiap233-videos como irmãos (mesmo diretório pai).
# Requer: terraform, aws, docker, kubectl. Opção: DOCKER_PLATFORM=linux/amd64 para Mac Apple Silicon.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HACKATHON_ROOT="$(cd "$INFRA_ROOT/.." && pwd)"
USERS_ROOT="$HACKATHON_ROOT/hack-fiap233-users"
VIDEOS_ROOT="$HACKATHON_ROOT/hack-fiap233-videos"
REGION="${AWS_REGION:-us-east-1}"
# Mac Apple Silicon: export DOCKER_PLATFORM=linux/amd64
DOCKER_BUILD_OPTS="${DOCKER_PLATFORM:+--platform $DOCKER_PLATFORM}"

log() { echo "[deploy_services] $*" >&2; }

if [[ ! -d "$USERS_ROOT" || ! -d "$VIDEOS_ROOT" ]]; then
  log "Erro: esperado hack-fiap233-users e hack-fiap233-videos em $HACKATHON_ROOT"
  exit 1
fi

cd "$INFRA_ROOT"

EKS_NAME="$(terraform output -raw eks_cluster_name 2>/dev/null || true)"
if [[ -z "$EKS_NAME" ]]; then
  log "Erro: rode primeiro o setup_infra.sh (terraform apply) para obter o cluster EKS."
  exit 1
fi

ECR_USERS="$(terraform output -raw ecr_users_url)"
ECR_VIDEOS="$(terraform output -raw ecr_videos_url)"

# 1. kubectl
log "Configurando kubectl para o cluster $EKS_NAME..."
aws eks update-kubeconfig --name "$EKS_NAME" --region "$REGION"

# 2. Login ECR (registry é o host da URL do repositório)
ECR_REGISTRY="${ECR_USERS%/*}"
log "Login no ECR $ECR_REGISTRY..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

# 3. Build e push
log "Build e push da imagem users..."
docker build $DOCKER_BUILD_OPTS -t "${ECR_USERS}:latest" "$USERS_ROOT"
docker push "${ECR_USERS}:latest"

log "Build e push da imagem videos..."
docker build $DOCKER_BUILD_OPTS -t "${ECR_VIDEOS}:latest" "$VIDEOS_ROOT"
docker push "${ECR_VIDEOS}:latest"

# 4. Atualizar image nos manifests (preserva indentação YAML; macOS sed -i '', Linux sed -i)
inplace_sed() {
  local file="$1"
  local replacement="$2"
  local pattern="s|^\([[:space:]]*image:[[:space:]]*\).*|\1$replacement|"
  if sed --version 2>/dev/null | grep -q GNU; then
    sed -i "$pattern" "$file"
  else
    sed -i '' "$pattern" "$file"
  fi
}
inplace_sed "$USERS_ROOT/k8s/deployment.yaml" "${ECR_USERS}:latest"
inplace_sed "$VIDEOS_ROOT/k8s/deployment.yaml" "${ECR_VIDEOS}:latest"

# 5. Deploy no EKS
log "Aplicando manifests no EKS..."
kubectl apply -f "$USERS_ROOT/k8s/"
kubectl apply -f "$VIDEOS_ROOT/k8s/"

log "Aguardando rollout..."
kubectl rollout status deployment/users-deployment --timeout=120s
kubectl rollout status deployment/videos-deployment --timeout=120s

log "Deploy concluído. Teste: curl \$(terraform output -raw api_gateway_url)users/health"
