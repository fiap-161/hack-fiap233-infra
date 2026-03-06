# ADR-0004: RabbitMQ para fila de processamento de vídeo (mensageria)

**Status:** Aceito  
**Data:** 2025-03  
**Autores:** Time hack-fiap233

## Contexto

O requisito do hackathon exige **mensageria (RabbitMQ ou Kafka)** para: (1) não perder requisição em picos e (2) processar mais de um vídeo ao mesmo tempo. 
O padrão é **fila de jobs**: o serviço Videos publica um job (ex.: `video_id`, `user_id`, `object_key`) na fila; workers consomem, processam o vídeo e dão ack. 
Em caso de falha, mensagens podem ser encaminhadas para uma DLQ (Dead Letter Queue). É necessário escolher e provisionar um broker de mensageria na infraestrutura (Fase 2). Exemplos de brokers utilizados para este tipo de arquitetura incluem **RabbitMQ**, **Apache Kafka** e **Amazon SQS** — para este projeto, avaliaremos principalmente RabbitMQ e Kafka conforme requisito do hackathon.

## Decisão

- **Broker escolhido:** **RabbitMQ**.
- **Provisionamento:** RabbitMQ no EKS via Helm (Bitnami), em rede privada; credenciais no AWS Secrets Manager; filas `video.process` e `video.process.dlq` documentadas (a aplicação declara as filas ao publicar/consumir).
- **Alternativa rejeitada:** Kafka (Amazon MSK ou self-managed) — maior complexidade operacional e conceitual para o caso de uso atual (task queue).

## RabbitMQ vs Kafka — pontos positivos e negativos

| Critério | RabbitMQ | Kafka |
|----------|----------|--------|
| **Modelo** | Fila push, ack, DLQ nativo | Log pull, consumer groups, offsets |
| **Complexidade** | Menor: queues, exchanges, bindings | Maior: tópicos, partições, rebalanceamento, retenção |
| **Caso de uso** | Task queue / job processing (1 msg = 1 job) | Event streaming, replay, múltiplos consumidores com offsets |
| **Operação** | Mais simples; Helm no EKS ou Amazon MQ | MSK ou cluster próprio; mais componentes e tuning |
| **Throughput** | Suficiente para milhares de msgs/s | Muito alto (milhões/s); não necessário aqui |
| **DLQ / retry** | Nativo (dead-letter exchange) | Implementar com tópicos separados e lógica |
| **Replay** | Não é foco | Replay por offset; útil para event sourcing |
| **Custo/setup** | Menor (um deployment no EKS) | Maior (MSK ou cluster dedicado) |

Para o escopo atual (fila de processamento de vídeo, DLQ, não perder requisição, hackathon com foco em evitar complexidade), **RabbitMQ atende melhor**: menos conceitos, menos operação, padrão natural de “fila de trabalho”.

## Alternativas consideradas

- **Kafka (Amazon MSK):** oferta gerenciada na AWS, alto throughput e retenção. Rejeitado por ser overkill para uma fila de jobs, maior curva de aprendizado (partições, consumer groups, offsets) e custo/operação maiores.
- **Amazon MQ for RabbitMQ:** RabbitMQ gerenciado na AWS. Alternativa válida; optamos por RabbitMQ no EKS para manter tudo no mesmo cluster, menor custo em ambiente de hackathon e controle total no Terraform (Helm).

## Consequências

- **Positivas:** padrão claro de producer/consumer e DLQ; menor complexidade; credenciais centralizadas no Secrets Manager; filas em rede privada.
- **Negativas:** se no futuro houver necessidade de event streaming ou replay em grande escala, pode ser necessário avaliar Kafka.
- **Neutras:** os serviços (Videos e worker) declaram as filas ao usar (queue declare); a infra documenta os nomes (`video.process`, `video.process.dlq`) e expõe o endpoint e o secret ARN via outputs.

## Notas

- Topologia: exchange (ou default) → fila `video.process`; em falha após retries → DLQ `video.process.dlq`.
- Referência: [ROADMAP Fase 2 — Mensageria](../../ROADMAP-HACKATHON-FIAP.md), [Architecture — Evolução prevista](architecture.md#6-evolução-prevista-roadmap).
