# ADR-0001: Uso de AWS EKS e API Gateway como borda

**Status:** Aceito  
**Data:** 2025-02  
**Autores:** Time hack-fiap233

## Contexto

O sistema precisa ser escalável, implantado em containers e expor uma API HTTP pública para clientes (usuários que enviam vídeos e fazem download). É necessário um único ponto de entrada que roteie para os microsserviços (Users e Videos) sem expor os backends diretamente à internet. O ambiente de entrega é AWS (incl. AWS Academy).

## Decisão

- **Orquestração:** usar **Amazon EKS (Kubernetes)** para rodar os microsserviços (Users e Videos) em Pods, com possibilidade de escalar horizontalmente e evoluir para mensageria e workers no mesmo cluster.
- **Borda:** usar **API Gateway HTTP API (v2)** como único ponto de entrada público. O tráfego é roteado para um **NLB interno** (na VPC) via **VPC Link**, e o NLB encaminha por porta para os NodePorts dos serviços no EKS (Users na porta 8081 -> 30081, Videos na 8082 -> 30082).
- **Rede:** VPC com subnets públicas e privadas; EKS e RDS em subnets privadas; sem exposição direta dos Pods ou bancos à internet.

## Alternativas consideradas

- **Application Load Balancer (ALB) + ECS:** ALB poderia rotear por path, mas o uso de API Gateway permite integração nativa com Lambda (Authorizer) e um único endpoint público com roteamento por rota (`/users/*`, `/videos/*`), alinhado ao requisito de “uma API” para o cliente.
- **Expor serviços via LoadBalancer/NodePort diretamente:** aumentaria superfície de ataque e exigiria gerenciar TLS e autenticação em cada serviço; rejeitado.
- **Docker Compose em EC2:** atende menos ao requisito de escalabilidade e à stack recomendada (Kubernetes); rejeitado para o ambiente AWS.

## Consequências

- **Positivas:** escalabilidade do EKS; API Gateway gerencia throttling, CORS e integração com Lambda (authorizer); rede privada para dados e serviços.
- **Negativas:** custo e complexidade do EKS; dependência de VPC Link e NLB; necessidade de configurar kubectl e imagens (ECR) para deploy.
- **Neutras:** decisões de autorização (JWT) e de banco de dados ficam em ADRs separados.
