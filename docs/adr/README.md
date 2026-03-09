# Architecture Decision Records (ADR)

Este diretório contém as decisões de arquitetura do projeto **hack-fiap233** (infraestrutura e desenho do sistema de processamento de vídeos).

## Índice

| ADR | Título |
|-----|--------|
| [0000](0000-template.md) | Template para novos ADRs |
| [0001](0001-aws-eks-and-api-gateway.md) | Uso de AWS EKS e API Gateway como borda |
| [0002](0002-lambda-authorizer-for-jwt.md) | Lambda Authorizer para validação JWT |
| [0003](0003-database-per-service.md) | Database per service (RDS por microsserviço) |

## Como adicionar um novo ADR

1. Copie o [template](0000-template.md).
2. Salve como `NNNN-titulo-kebab-case.md` (próximo número sequencial).
3. Preencha Contexto, Decisão, Consequências e, se útil, Alternativas consideradas.
