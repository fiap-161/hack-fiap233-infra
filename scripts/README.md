# Scripts e migrations

Este diretório contém scripts de infraestrutura e de **migrations** dos bancos (usersdb e videosdb).

## Scripts de infra e deploy

| Script | Descrição |
|--------|-----------|
| `setup_infra.sh` | Bootstrap (S3 state) + `terraform apply` — provisiona toda a infra. |
| `deploy_services.sh` | Configura kubectl, login ECR, build/push das imagens, atualiza manifests e aplica no EKS. |
| `run_migrations.sh` | Aplica as migrations SQL nos bancos (ver seção abaixo). |

Uso rápido (a partir da raiz de `hack-fiap233-infra`): `./scripts/setup_infra.sh` e em seguida `./scripts/deploy_services.sh`. Ver [README principal](../README.md#passo-a-passo).

## Estrutura

```
scripts/
├── README.md            # Este arquivo
├── setup_infra.sh       # Bootstrap + Terraform apply
├── deploy_services.sh   # Deploy dos microsserviços no EKS
├── run_migrations.sh    # Aplica todas as migrations (users + videos)

migrations/
├── users/              # SQL para o banco usersdb
│   └── 001_initial_schema.sql
└── videos/             # SQL para o banco videosdb
    └── 001_initial_schema.sql
```

## Pré-requisitos

- **psql** (cliente PostgreSQL) instalado
- Acesso de rede aos RDS (host e porta). Os RDS ficam em **subnets privadas**; é necessário executar de um ambiente que tenha acesso à VPC (por exemplo:
  - Pod no EKS (Job ou init container),
  - Bastion host na VPC,
  - Ou túnel/port-forward a partir de um Pod que tenha acesso).

## Como executar

### Opção 1: Variáveis de ambiente

Defina as variáveis para **Users DB** e **Videos DB** e execute o script a partir da raiz do repositório de infra:

```bash
cd hack-fiap233-infra

# Users DB (substitua pelos valores reais; ex.: obtidos do Secrets Manager)
export USERS_DB_HOST="<rds-users-endpoint>"
export USERS_DB_PORT="5432"
export USERS_DB_USER="dbadmin"
export USERS_DB_PASSWORD="<senha>"
export USERS_DB_NAME="usersdb"

# Videos DB
export VIDEOS_DB_HOST="<rds-videos-endpoint>"
export VIDEOS_DB_PORT="5432"
export VIDEOS_DB_USER="dbadmin"
export VIDEOS_DB_PASSWORD="<senha>"
export VIDEOS_DB_NAME="videosdb"

./scripts/run_migrations.sh
```

### Opção 2: Credenciais via AWS Secrets Manager

Se você estiver em um ambiente com **AWS CLI** configurado e acesso à VPC dos RDS, pode usar os secrets já criados pelo Terraform:

```bash
cd hack-fiap233-infra
export AWS_REGION=us-east-1

# Nomes dos secrets (padrão do Terraform)
export MIGRATE_USERS_SECRET="hack-fiap233/users/db-credentials"
export MIGRATE_VIDEOS_SECRET="hack-fiap233/videos/db-credentials"

./scripts/run_migrations.sh
```

O script irá obter host, port, username, password e dbname de cada secret e chamar `psql` para cada arquivo em `migrations/users/` e `migrations/videos/` (em ordem lexicográfica).

### Opção 3: Aplicar manualmente com psql

Obtenha as credenciais do Secrets Manager:

```bash
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/users/db-credentials \
  --region us-east-1 --query SecretString --output text | jq -r '
  "postgresql://\(.username):\(.password)@\(.host):\(.port)/\(.dbname)?sslmode=require"
'
```

Conecte (de um host com acesso ao RDS) e execute os arquivos:

```bash
psql "<connection_string>" -f migrations/users/001_initial_schema.sql
psql "<connection_string_videos>" -f migrations/videos/001_initial_schema.sql
```

## Ordem das migrations

- **users:** `001_initial_schema.sql` (tabela `users` e índice único em `email`).
- **videos:** `001_initial_schema.sql` (tabela `videos`).

Novas migrations devem ser nomeadas de forma ordenada (ex.: `002_add_user_id_to_videos.sql`) e documentadas no README ou no próprio arquivo SQL.

## Integração com os aplicativos

Os serviços **hack-fiap233-users** e **hack-fiap233-videos** podem continuar a rodar migrations no startup (como hoje em Go) desde que o schema seja **compatível** com estes scripts. Estes arquivos são a **fonte única de verdade** para a infraestrutura; ao alterar o schema, atualize primeiro os scripts aqui e, em seguida, o código dos serviços.
