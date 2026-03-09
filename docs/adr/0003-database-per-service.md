# ADR-0003: Database per service (RDS por microsserviço)

**Status:** Aceito  
**Data:** 2025-02  
**Autores:** Time hack-fiap233

## Contexto

O sistema possui dois microsserviços (Users e Videos), cada um com necessidade de persistência. É necessário definir como os dados são armazenados: banco compartilhado ou banco dedicado por serviço, alinhado às boas práticas de microsserviços e ao requisito de escalabilidade.

## Decisão

- **Modelo:** **database per service**. Cada microsserviço possui seu próprio banco de dados PostgreSQL em instâncias **Amazon RDS** separadas: **usersdb** (serviço Users) e **videosdb** (serviço Videos).
- **Acesso:** apenas o respectivo serviço acessa seu banco; não há acesso cross-database. Dados de usuário (ex.: email para notificação) são repassados entre serviços via payload de mensagens (ex.: SNS) ou headers (X-User-Id, X-User-Email), não via JOIN entre bancos.
- **Credenciais:** cada RDS tem usuário e senha gerados pelo Terraform e armazenados no **AWS Secrets Manager** (`hack-fiap233/users/db-credentials`, `hack-fiap233/videos/db-credentials`). Os Pods recebem as variáveis de conexão via montagem do secret ou variáveis de ambiente configuradas no deployment.
- **Schemas:** definidos em scripts SQL versionados no repositório de infra (`migrations/users/`, `migrations/videos/`), aplicados manualmente ou no pipeline após a criação dos RDS.

## Alternativas consideradas

- **Banco único com schemas separados:** reduz custo de infra mas acopla evolução dos schemas e exige disciplina rígida de acesso; rejeitado para manter fronteiras claras.
- **Banco único compartilhado:** viola o princípio de microsserviços e dificulta evolução e escalabilidade independente; rejeitado.
- **RDS Proxy:** pode ser introduzido depois para pooling de conexões; não adotado na primeira versão.

## Consequências

- **Positivas:** evolução independente dos schemas; isolamento de falhas; cada serviço escala e faz backup de forma independente; alinhado ao padrão de microsserviços.
- **Negativas:** dois RDS (custo maior); não há transações distribuídas entre Users e Videos; dados de usuário precisam ser propagados por API ou mensageria quando necessário (ex.: user_email para notificação).
- **Neutras:** migrations versionadas na infra servem como fonte única de verdade do schema; os aplicativos podem manter migrations no código em paralelo desde que compatíveis com os scripts da infra.
