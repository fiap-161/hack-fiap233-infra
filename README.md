# hack-fiap233-infra

Infraestrutura Terraform para provisionar um cluster EKS na AWS com arquitetura de microsserviços, usando API Gateway como ponto de entrada público.

- **Documentação da arquitetura:** [docs/architecture.md](docs/architecture.md) (visão C4, diagramas, fluxo de autorização).
- **Decisões de arquitetura (ADR):** [docs/adr/](docs/adr/).
- **Scripts de banco (migrations):** [scripts/README.md](scripts/README.md).

## Arquitetura

```
Cliente
   │
   ▼
API Gateway (HTTP API — público)
   │
   ▼
VPC Link
   │
   ▼
NLB interno (private subnets)
   ├── porta 8081 → NodePort 30081 → PODs do serviço de Usuários → RDS Postgres (usersdb)
   └── porta 8082 → NodePort 30082 → PODs do serviço de Vídeos  → RDS Postgres (videosdb)
```

### Autorização (Lambda Authorizer)

As rotas protegidas (`/users/*` exceto login/register, `/videos/*`) passam por um **Lambda Authorizer** que:

1. Lê o header `Authorization: Bearer <JWT>`
2. Valida assinatura e expiração do JWT usando o mesmo `JWT_SECRET` do Secrets Manager
3. Retorna `isAuthorized: true` e um **context** com `user_id` (claim `sub`) e `email`
4. O API Gateway repassa esse context aos backends como **headers**:
   - **`X-User-Id`** — ID do usuário (claim `sub` do JWT)
   - **`X-User-Email`** — e-mail do usuário

Os serviços **Users** e **Videos** não precisam validar JWT nem ter o secret: basta ler `X-User-Id` (e opcionalmente `X-User-Email`) do request. A validação é feita de forma centralizada na AWS.

## Pré-requisitos

- Terraform >= 1.5.0
- Docker instalado e rodando
- AWS CLI configurado com credenciais da AWS Academy
- `kubectl` instalado

## Estrutura dos Repositórios

```
hackathon/
├── hack-fiap233-infra/        # Este repositório (infraestrutura)
│   ├── bootstrap/             # S3 bucket para remote state
│   ├── docs/                  # Documentação da arquitetura
│   │   ├── architecture.md   # Visão C4, diagramas, fluxos
│   │   └── adr/              # Architecture Decision Records
│   ├── migrations/            # Scripts SQL versionados (fonte de verdade do schema)
│   │   ├── users/             # usersdb
│   │   └── videos/            # videosdb
│   ├── scripts/               # Scripts de aplicação (migrations, etc.)
│   │   ├── README.md
│   │   └── run_migrations.sh
│   ├── modules/               # Módulos Terraform (vpc, eks, nlb, api_gateway, rds)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
├── hack-fiap233-users/        # Microsserviço de usuários (Go)
│   ├── main.go
│   ├── Dockerfile
│   └── k8s/
└── hack-fiap233-videos/       # Microsserviço de vídeos (Go)
    ├── main.go
    ├── Dockerfile
    └── k8s/
```

---

## Passo a Passo

### Caminho rápido (recomendado)

Três comandos cobrem infraestrutura e deploy dos microsserviços. **Execute sempre na raiz do repositório** (pasta `hack-fiap233-infra`), não dentro de `scripts/`:

```bash
cd hack-fiap233-infra   # se ainda não estiver na raiz do repositório

# Se aparecer "permission denied", dê permissão de execução uma vez:
chmod +x scripts/setup_infra.sh scripts/deploy_services.sh

# 1. Infraestrutura (bootstrap + Terraform apply)
./scripts/setup_infra.sh

# 2. Deploy dos serviços (kubectl, ECR login, build, push, apply no EKS)
./scripts/deploy_services.sh
```

No Mac com Apple Silicon (M1/M2/M3), use build multi-plataforma:

```bash
DOCKER_PLATFORM=linux/amd64 ./scripts/deploy_services.sh
```

#### Se deu 403 (Access Denied) no bootstrap

O LabRole da AWS Academy pode não ter permissão para versionamento do S3. O bootstrap já foi ajustado para não usar versionamento. Se você rodou o bootstrap antes dessa alteração, o state ainda pode referenciar o recurso antigo; nesse caso, remova-o do state e rode de novo:

```bash
cd hack-fiap233-infra/bootstrap
terraform init
terraform state rm 'aws_s3_bucket_versioning.tfstate'   # só remove do state, não chama a AWS
cd ..
./scripts/setup_infra.sh
```

#### Se deu 409 (BucketAlreadyExists)

Nomes de bucket S3 são globais na AWS. O bootstrap passou a usar um nome único por conta: `hack-fiap233-tfstate-<ACCOUNT_ID>`. Rode de novo `./scripts/setup_infra.sh`; o script já configura o backend da infra principal com o bucket criado no bootstrap.

#### Como saber se o setup aplicou com sucesso

- **Bootstrap:** ao final deve aparecer `Apply complete! Resources: X added, 0 changed, 0 destroyed` e não deve haver mensagem de erro em vermelho.
- **Infra principal:** o mesmo: `Apply complete!` e, em seguida, você pode rodar `terraform output` na raiz do repo e ver `api_gateway_url`, `eks_cluster_name`, `ecr_users_url`, etc.
- **Teste rápido:** depois do setup completo, `kubectl get nodes` (após o passo 2, deploy) deve listar os nodes do EKS.

É seguro executar `./scripts/setup_infra.sh` várias vezes: o Terraform só altera o que for necessário (idempotente).

### 3. Testar

```bash
cd hack-fiap233-infra
API_URL=$(terraform output -raw api_gateway_url)
curl "${API_URL}users/health"
curl "${API_URL}videos/health"
curl "${API_URL}users/hello"
curl "${API_URL}videos/hello"
```

Respostas esperadas:

```json
{"message":"Hello from Users Service","method":"GET","path":"/users/hello"}
{"message":"Hello from Videos Service","method":"GET","path":"/videos/hello"}
```

---

## Passo a Passo Completo (manual)

Se preferir executar cada etapa à mão (útil para debug ou aprendizado):

| # | O que faz |
|---|-----------|
| 1 | Bucket S3 para remote state (bootstrap) |
| 2 | Provisionar infra (EKS, ECR, RDS, API Gateway) |
| 3 | Configurar `kubectl` |
| 4 | Login no ECR |
| 5 | Build e push das imagens Docker |
| 6 | Atualizar `image` nos manifests K8s |
| 7 | Deploy no EKS (`kubectl apply`) |
| 8 | Testar (curl) |


### Passo 1 — Criar o bucket S3 para remote state

Execute apenas uma vez:

```bash
cd hack-fiap233-infra/bootstrap
terraform init
terraform apply -auto-approve
cd ..
```

### Passo 2 — Provisionar toda a infraestrutura

```bash
cd hack-fiap233-infra
terraform init
terraform apply -auto-approve
```

Ao final, anote os outputs:

```
api_gateway_url    = "https://xxxxx.execute-api.us-east-1.amazonaws.com/"
eks_cluster_name   = "hack-fiap233-eks"
ecr_users_url      = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users"
ecr_videos_url     = "432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos"
rds_users_endpoint = "..."
rds_videos_endpoint = "..."
redis_endpoint      = "hack-fiap233-redis.xxxxx.cache.amazonaws.com"
redis_port          = 6379
notification_sns_topic_arn = "arn:aws:sns:us-east-1:xxxxx:hack-fiap233-video-processing-failed"
```

### Passo 3 — Configurar kubectl

```bash
aws eks update-kubeconfig --name hack-fiap233-eks --region us-east-1
```

Verifique se os nodes estão prontos:

```bash
kubectl get nodes
```

### Passo 4 — Login no ECR

```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 432686365376.dkr.ecr.us-east-1.amazonaws.com
```

### Passo 5 — Build e push das imagens Docker

```bash
# Users
docker build -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest ../hack-fiap233-users
docker push 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest

# Videos
docker build -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos:latest ../hack-fiap233-videos
docker push 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-videos:latest
```

> **Nota:** se você estiver em Mac com Apple Silicon (M1/M2/M3), faça build multi-platform:
> ```bash
> docker build --platform linux/amd64 -t 432686365376.dkr.ecr.us-east-1.amazonaws.com/hack-fiap233-users:latest ../hack-fiap233-users
> ```

### Passo 6 — Atualizar as imagens nos manifests K8s

Substitua os placeholders nos arquivos de deployment:

```bash
# Pega a URL do ECR do output do Terraform
ECR_USERS=$(terraform output -raw ecr_users_url)
ECR_VIDEOS=$(terraform output -raw ecr_videos_url)

# Atualiza os deployments
sed -i '' "s|ECR_USERS_URL|${ECR_USERS}|" ../hack-fiap233-users/k8s/deployment.yaml
sed -i '' "s|ECR_VIDEOS_URL|${ECR_VIDEOS}|" ../hack-fiap233-videos/k8s/deployment.yaml
```

### Passo 7 — Deploy no EKS

```bash
kubectl apply -f ../hack-fiap233-users/k8s/
kubectl apply -f ../hack-fiap233-videos/k8s/
```

Acompanhe o rollout:

```bash
kubectl rollout status deployment/users-deployment
kubectl rollout status deployment/videos-deployment
```

### Passo 8 — Testar

```bash
# Health checks
curl https://$(terraform output -raw api_gateway_url)users/health
curl https://$(terraform output -raw api_gateway_url)videos/health

# Endpoints
curl https://$(terraform output -raw api_gateway_url)users/hello
curl https://$(terraform output -raw api_gateway_url)videos/hello
```

Respostas esperadas:

```json
{"message":"Hello from Users Service","method":"GET","path":"/users/hello"}
{"message":"Hello from Videos Service","method":"GET","path":"/videos/hello"}
```

---

## Credenciais dos Bancos de Dados

As credenciais são geradas automaticamente e armazenadas no **AWS Secrets Manager**:

```bash
# Users DB
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/users/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .

# Videos DB
aws secretsmanager get-secret-value \
  --secret-id hack-fiap233/videos/db-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq .
```

---

## Cache (Redis)

O requisito de stack **PostgreSQL + Redis** é atendido com **Amazon ElastiCache for Redis** em modo single node (1 réplica), em rede privada.

- **Provisionamento:** módulo `modules/elasticache` — subnet group (subnets privadas), security group (acesso apenas a partir dos nós EKS), replication group Redis.
- **Endpoint e porta:** após `terraform apply`, use os outputs `redis_endpoint` e `redis_port`. As aplicações no EKS (Users, Videos) devem usar essas variáveis para conectar ao Redis (ex.: cache de sessão/token ou cache da listagem de status de vídeos).
- **Variáveis:** `redis_node_type` (default `cache.t3.micro`), `redis_num_cache_clusters` (1), `redis_engine_version` (7.0), `redis_port` (6379).
- **Uso nos serviços:** definir no serviço (ex.: Videos) o uso inicial — cache da listagem de status com TTL curto ou cache de sessão no Users. Configurar nos deployments via env: `REDIS_HOST`, `REDIS_PORT`.

Sem auth token por padrão (transit_encryption_enabled = false); at-rest encryption está habilitada. Para produção com AUTH, pode-se adicionar `auth_token` no módulo e habilitar transit encryption.

---

## Notificação em caso de erro (SNS + Lambda + SES)

Requisito: em caso de falha no processamento de vídeo, o usuário é notificado por e-mail. **Abordagem adotada (Opção 1):** SNS + Lambda + SES em sandbox; remetente e destinatários de teste precisam ser **verificados no SES** (ver abaixo).

- **Fluxo:** o worker do serviço **Videos** publica uma mensagem no tópico SNS `hack-fiap233-video-processing-failed` com payload JSON: `user_id`, `user_email`, `video_id`, `error_message`. A **Lambda** é acionada pelo SNS, monta um e-mail HTML estilizado (template FiapX Videos) e envia via **Amazon SES** para `user_email`.
- **Onde está:** módulo Terraform `modules/notification` (SNS topic, Lambda Node.js 18, subscription SNS→Lambda, identidade SES do remetente, IAM).
- **Outputs:** `notification_sns_topic_arn` — use no serviço Videos para publicar em caso de falha (ex.: SDK AWS SNS Publish com esse ARN).

Antes do `terraform apply`, defina no `terraform.tfvars` (ou `-var`):

```hcl
ses_sender_email = "seu-email@exemplo.com"
```

Esse será o endereço **remetente** (“De”) dos e-mails. Ele precisa existir e será registrado no SES pelo Terraform; a verificação (confirmação por link) é feita manualmente no console, conforme os passos abaixo.

---

### O que fazer após o `terraform apply` para a notificação funcionar

O Terraform cria o tópico SNS, a Lambda e registra o remetente no SES. Em **sandbox**, o SES só entrega e-mails para endereços **verificados**. “Verificado” significa: você cadastrou o e-mail no SES e confirmou o acesso clicando no link que a AWS envia para esse endereço.

Siga estes passos **depois** do `terraform apply`:

#### 1. Verificar o e-mail remetente

O Terraform já criou a identidade no SES com o valor de `ses_sender_email`. A AWS envia um e-mail de confirmação para esse endereço.

1. Acesse o **Console AWS** → **Amazon SES** → **Verified identities** (ou **Identidades**).
2. Localize o e-mail que você definiu em `ses_sender_email` (status **Pending** ou **Verification pending**).
3. Abra a caixa de entrada desse e-mail, localize a mensagem da AWS e **clique no link de verificação**.
4. Volte ao console; o status deve mudar para **Verified**. Enquanto não estiver **Verified**, a Lambda não conseguirá enviar (erro de remetente não verificado).

#### 2. Verificar os e-mails destinatários (sandbox)

No sandbox do SES, você **só pode enviar para endereços que também estejam verificados**. Quem for receber a notificação de “erro no processamento” (o `user_email` do payload) precisa estar verificado.

Para cada e-mail que for usar como destinatário nos testes (o seu, do time ou o e-mail usado no cadastro do usuário no sistema):

1. No console SES → **Verified identities** → **Create identity**.
2. Escolha **Email address** e informe o endereço (ex.: o e-mail com que o usuário se cadastrou no sistema).
3. Confirme. A AWS envia um e-mail para esse endereço.
4. Abra a caixa de entrada e **clique no link de verificação** enviado pela AWS.
5. Quando o status ficar **Verified**, a Lambda poderá enviar notificações para esse endereço.

**Resumo:** Remetente = verificado (passo 1). Cada destinatário de teste = verificado (passo 2). Só então a notificação funcionará de ponta a ponta.

#### 3. Testar o fluxo (opcional)

Após remetente e destinatários verificados, provar o fluxo:

- Garanta que o serviço **Videos** está publicando no tópico SNS em caso de falha (payload com `user_id`, `user_email`, `video_id`, `error_message`).
- Use como `user_email` um endereço que você já verificou no passo 2. Dispare uma falha de processamento (ex.: vídeo inválido) e confira se o e-mail chegou na caixa de entrada (e no spam, se aplicável).

---

## Scripts de banco / Migrations

Os schemas dos bancos **usersdb** e **videosdb** estão definidos em **migrations versionadas** em `migrations/users/` e `migrations/videos/`. São a fonte única de verdade do schema para a infraestrutura.

**Como aplicar:** execute de um ambiente com acesso de rede aos RDS (por exemplo, dentro da VPC ou via port-forward de um Pod). Opções:

1. **Variáveis de ambiente** — defina `USERS_DB_HOST`, `USERS_DB_PORT`, `USERS_DB_USER`, `USERS_DB_PASSWORD`, `USERS_DB_NAME` (e o mesmo para `VIDEOS_DB_*`) e rode:
   ```bash
   ./scripts/run_migrations.sh
   ```
2. **Secrets Manager** — defina `MIGRATE_USERS_SECRET=hack-fiap233/users/db-credentials` e `MIGRATE_VIDEOS_SECRET=hack-fiap233/videos/db-credentials` (e `AWS_REGION`) e execute o mesmo script. Requer AWS CLI e `jq`.

Documentação completa: [scripts/README.md](scripts/README.md).

### O que fazer ao alterar o banco de dados

Quando for necessário implementar uma alteração de schema (nova coluna, tabela, índice, etc.):

1. **Criar uma nova migration** no repositório de infra:
   - **Users DB:** novo arquivo em `migrations/users/` com nome ordenado, ex.: `002_add_notification_preference.sql`.
   - **Videos DB:** novo arquivo em `migrations/videos/`, ex.: `002_add_user_id_and_status.sql`.
   - Usar apenas DDL compatível com o que já existe (evitar dropar dados em produção; preferir `ADD COLUMN`, `CREATE INDEX`, novas tabelas).

2. **Documentar no próprio arquivo SQL** (comentário no topo): descrição da alteração e, se relevante, dependência de alguma migration anterior.

3. **Atualizar o código do microsserviço** (hack-fiap233-users ou hack-fiap233-videos) para usar o novo schema: modelos, queries, migrations no startup (se ainda houver) devem refletir o mesmo schema.

4. **Aplicar a migration** em cada ambiente (dev, staging, prod):
   - De um host com acesso ao RDS, rodar `./scripts/run_migrations.sh` (o script executa todos os `.sql` em ordem lexicográfica, então `002_...` roda após `001_...`).
   - Ou aplicar manualmente com `psql` nos ambientes em que o script não tiver acesso à rede.

5. **Fazer deploy do(s) serviço(s)** após o schema estar aplicado, para que a nova versão do código use as novas colunas/tabelas.

**Ordem recomendada:** migration na infra → aplicar no banco → deploy do serviço. Evitar deploy do serviço antes de aplicar a migration (pode quebrar se o código passar a depender do novo schema).

---

## CI/CD com GitHub Actions

Todos os passos podem ser automatizados. Configure estas secrets no repositório GitHub em **Settings > Secrets and variables > Actions**:

| Secret | Descrição |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key da conta AWS Academy |
| `AWS_SECRET_ACCESS_KEY` | Secret Key da conta AWS Academy |
| `AWS_SESSION_TOKEN` | Session Token da AWS Academy (rotaciona a cada sessão) |

### Workflow — Provisionar Infraestrutura

Arquivo `.github/workflows/infra.yml`:

```yaml
name: Terraform Infrastructure

on:
  push:
    branches: [main]
    paths:
      - '*.tf'
      - 'modules/**'
      - 'terraform.tfvars'
  workflow_dispatch:

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_SESSION_TOKEN: ${{ secrets.AWS_SESSION_TOKEN }}
  AWS_REGION: us-east-1

jobs:
  terraform:
    name: Terraform Apply
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        run: terraform apply -auto-approve tfplan
```

### Workflow — Deploy dos Microsserviços

Arquivo `.github/workflows/deploy.yml`:

```yaml
name: Deploy to EKS

on:
  workflow_dispatch:
    inputs:
      service:
        description: 'Serviço para deploy'
        required: true
        type: choice
        options:
          - users
          - videos
          - all

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  AWS_SESSION_TOKEN: ${{ secrets.AWS_SESSION_TOKEN }}
  AWS_REGION: us-east-1
  EKS_CLUSTER_NAME: hack-fiap233-eks

jobs:
  deploy:
    name: Deploy ${{ github.event.inputs.service }}
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure kubectl
        run: aws eks update-kubeconfig --name $EKS_CLUSTER_NAME --region $AWS_REGION

      - name: Deploy users
        if: github.event.inputs.service == 'users' || github.event.inputs.service == 'all'
        run: kubectl apply -f k8s/users/

      - name: Deploy videos
        if: github.event.inputs.service == 'videos' || github.event.inputs.service == 'all'
        run: kubectl apply -f k8s/videos/

      - name: Verify rollout users
        if: github.event.inputs.service == 'users' || github.event.inputs.service == 'all'
        run: kubectl rollout status deployment/users-deployment --timeout=120s

      - name: Verify rollout videos
        if: github.event.inputs.service == 'videos' || github.event.inputs.service == 'all'
        run: kubectl rollout status deployment/videos-deployment --timeout=120s
```

---

## Comandos Úteis

```bash
# Ver pods
kubectl get pods

# Ver services
kubectl get svc

# Logs de um pod
kubectl logs -f deployment/users-deployment

# Escalar replicas
kubectl scale deployment/users-deployment --replicas=3

# Credenciais DB
aws secretsmanager get-secret-value --secret-id hack-fiap233/users/db-credentials --query SecretString --output text | jq .
```

## Variáveis Configuráveis

| Variável | Padrão | Descrição |
|---|---|---|
| `region` | `us-east-1` | Regiao AWS |
| `project_name` | `hack-fiap233` | Nome do projeto |
| `kubernetes_version` | `1.29` | Versao do Kubernetes |
| `node_instance_types` | `["t3.medium"]` | Tipo de instancia dos nodes |
| `node_desired_size` | `2` | Quantidade desejada de nodes |
| `node_min_size` | `1` | Minimo de nodes |
| `node_max_size` | `3` | Maximo de nodes |
| `nlb_port_users` | `8081` | Porta do NLB para usuarios |
| `nlb_port_videos` | `8082` | Porta do NLB para videos |
| `node_port_users` | `30081` | NodePort para usuarios |
| `node_port_videos` | `30082` | NodePort para videos |
| `rds_instance_class` | `db.t3.micro` | Classe da instancia RDS |
| `rds_engine_version` | `16.6` | Versao do PostgreSQL |
| `notification_topic_name` | `video-processing-failed` | Nome do topico SNS para falhas de processamento |
| `ses_sender_email` | — (obrigatorio) | E-mail remetente SES (deve ser verificado no console SES) |
| `notification_email_subject` | `FiapX Videos — Erro no processamento do seu vídeo` | Assunto do e-mail de notificacao |

## AWS Academy

Este projeto usa o role `LabRole` existente na conta AWS Academy. Nenhum IAM Role, Policy ou attachment e criado pelo Terraform. O `AWS_SESSION_TOKEN` expira a cada sessao do lab — atualize-o antes de executar os comandos.

## Destruir a Infraestrutura

**Forma mais simples** (na raiz de `hack-fiap233-infra`):

```bash
./scripts/destroy_infra.sh
```

O script faz na ordem: (1) remove os recursos no EKS (users/videos), (2) `terraform destroy` da infra principal, (3) `terraform destroy` do bootstrap (bucket S3 do state).

**Manual**, se preferir:

```bash
# 1. Remover workloads do EKS (para o cluster poder ser destruído)
kubectl delete -f ../hack-fiap233-users/k8s/ --ignore-not-found
kubectl delete -f ../hack-fiap233-videos/k8s/ --ignore-not-found

# 2. Na raiz do repo: destruir a infraestrutura (EKS, ECR, RDS, API Gateway, etc.)
terraform destroy

# 3. Destruir o bucket de state
cd bootstrap && terraform destroy
```
