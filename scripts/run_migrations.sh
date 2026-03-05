#!/usr/bin/env bash
# run_migrations.sh — Aplica migrations SQL aos bancos usersdb e videosdb.
# Uso: variáveis de ambiente (USERS_DB_*, VIDEOS_DB_*) ou Secrets Manager (MIGRATE_USERS_SECRET, MIGRATE_VIDEOS_SECRET).
# Requer: psql. Para Secrets Manager: aws, jq. Execute de um ambiente com acesso de rede aos RDS (ex.: dentro da VPC).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_USERS="$REPO_ROOT/migrations/users"
MIGRATIONS_VIDEOS="$REPO_ROOT/migrations/videos"

log() { echo "[migrate] $*" >&2; }
run_psql() {
  local conn="$1"
  local file="$2"
  log "Applying $file"
  psql "$conn" -v ON_ERROR_STOP=1 -f "$file"
}

# Obtém variáveis de conexão do Secrets Manager (AWS).
# Secret deve ter: username, password, host, port, dbname
get_connection_vars() {
  local secret_name="${1:?secret name required}"
  local region="${AWS_REGION:-us-east-1}"
  local json
  json=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --region "$region" --query SecretString --output text 2>/dev/null || true)
  if [[ -z "$json" ]]; then
    return 1
  fi
  echo "$json"
}

# Monta string de conexão para psql a partir de env ou do secret.
# Uso: build_conn USERS_DB  ou  build_conn_from_secret "hack-fiap233/users/db-credentials"
build_conn_from_env() {
  local prefix="${1:?prefix required}" # USERS_DB ou VIDEOS_DB
  local host port user pass db
  host="${prefix}_HOST"
  port="${prefix}_PORT"
  user="${prefix}_USER"
  pass="${prefix}_PASSWORD"
  db="${prefix}_NAME"
  if [[ -z "${!host:-}" || -z "${!user:-}" || -z "${!pass:-}" || -z "${!db:-}" ]]; then
    return 1
  fi
  port="${!port:-5432}"
  echo "postgresql://${!user}:${!pass}@${!host}:${port}/${!db}?sslmode=require"
}

build_conn_from_secret() {
  local secret_name="${1:?}"
  local json
  json=$(get_connection_vars "$secret_name") || return 1
  local u p h pt d
  u=$(echo "$json" | jq -r .username)
  p=$(echo "$json" | jq -r .password)
  h=$(echo "$json" | jq -r .host)
  pt=$(echo "$json" | jq -r .port)
  d=$(echo "$json" | jq -r .dbname)
  echo "postgresql://${u}:${p}@${h}:${pt}/${d}?sslmode=require"
}

# --- Users DB
if build_conn_from_env "USERS_DB" >/dev/null 2>&1; then
  USERS_CONN=$(build_conn_from_env "USERS_DB")
elif [[ -n "${MIGRATE_USERS_SECRET:-}" ]]; then
  USERS_CONN=$(build_conn_from_secret "$MIGRATE_USERS_SECRET")
else
  log "Skip users: set USERS_DB_HOST/USER/PASSWORD/NAME or MIGRATE_USERS_SECRET"
  USERS_CONN=""
fi

# --- Videos DB
if build_conn_from_env "VIDEOS_DB" >/dev/null 2>&1; then
  VIDEOS_CONN=$(build_conn_from_env "VIDEOS_DB")
elif [[ -n "${MIGRATE_VIDEOS_SECRET:-}" ]]; then
  VIDEOS_CONN=$(build_conn_from_secret "$MIGRATE_VIDEOS_SECRET")
else
  log "Skip videos: set VIDEOS_DB_HOST/USER/PASSWORD/NAME or MIGRATE_VIDEOS_SECRET"
  VIDEOS_CONN=""
fi

if [[ -z "$USERS_CONN" && -z "$VIDEOS_CONN" ]]; then
  log "No database connection configured. See scripts/README.md"
  exit 0
fi

# Aplica migrations em ordem lexicográfica
if [[ -n "$USERS_CONN" && -d "$MIGRATIONS_USERS" ]]; then
  log "--- Users DB ---"
  for f in "$MIGRATIONS_USERS"/*.sql; do
    [[ -f "$f" ]] || continue
    run_psql "$USERS_CONN" "$f"
  done
fi

if [[ -n "$VIDEOS_CONN" && -d "$MIGRATIONS_VIDEOS" ]]; then
  log "--- Videos DB ---"
  for f in "$MIGRATIONS_VIDEOS"/*.sql; do
    [[ -f "$f" ]] || continue
    run_psql "$VIDEOS_CONN" "$f"
  done
fi

log "Done."
