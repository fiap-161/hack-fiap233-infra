# ADR-0002: Lambda Authorizer para validação JWT

**Status:** Aceito  
**Data:** 2025-02  
**Autores:** Time hack-fiap233

## Contexto

O sistema deve ser protegido por usuário e senha; após login, o cliente usa um token JWT para acessar as rotas de vídeos e de usuário autenticado. É necessário validar o JWT em toda requisição às rotas protegidas e repassar a identidade (user_id, email) aos microsserviços para autorização por recurso (ex.: listar apenas vídeos do usuário).

## Decisão

- **Onde validar:** a validação do JWT é feita no **API Gateway**, por meio de um **Lambda Authorizer** (request authorizer, payload format 2.0, simple response).
- **Secret:** o JWT é assinado com um secret único, armazenado no **AWS Secrets Manager** (`hack-fiap233/jwt-secret`). O Lambda Authorizer e o serviço Users (que emite o token no login) consomem o mesmo secret; o serviço de Videos não precisa do secret.
- **Contexto para o backend:** o Lambda, após validar o token, retorna `context` com `user_id` (claim `sub`) e `email`. O API Gateway mapeia esse contexto para os headers **`X-User-Id`** e **`X-User-Email`** nas integrações HTTP (Users e Videos). Os microsserviços leem apenas esses headers e não validam JWT nem acessam o secret.

## Alternativas consideradas

- **Validar JWT em cada microsserviço:** exigiria distribuir o JWT_SECRET para Users e Videos, aumentar superfície de ataque e duplicar lógica; rejeitado.
- **API Gateway JWT Authorizer nativo:** o HTTP API da AWS tem JWT authorizer para provedores OIDC/OAuth; como o token é emitido pelo próprio sistema (Users), o Lambda Authorizer oferece controle total sobre o secret e o formato do context; escolhido.
- **Serviço de auth dedicado (proxy):** um serviço que valida JWT e chama os demais internamente acrescentaria latência e um ponto único de falha; rejeitado para este escopo.

## Consequências

- **Positivas:** validação centralizada; microsserviços não manipulam JWT nem secret; headers padronizados (X-User-Id, X-User-Email) para autorização.
- **Negativas:** dependência do Lambda e do Secrets Manager; rotas públicas (login, register) devem ser configuradas sem authorizer no API Gateway.
- **Neutras:** o mesmo secret é usado pelo Terraform (Lambda + Secrets Manager) e pelo deployment do Users (injeção do secret no Pod).
