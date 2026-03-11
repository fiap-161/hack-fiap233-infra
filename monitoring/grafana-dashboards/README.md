# Dashboards Grafana

Pasta para definir dashboards como código (JSON). Podem ser carregados no Grafana via:

- **ConfigMap + sidecar:** chart do Grafana com `sidecar.dashboards.enabled` e ConfigMaps com label apropriada.
- **Import manual:** após o primeiro deploy, importar os JSON pela UI do Grafana (Create → Import).

## Dashboards sugeridos (roadmap)

- **Users:** latência das rotas (register, login, list), taxa de erro (4xx/5xx), requisições por segundo.
- **Videos:** latência de upload, listagem e download; fila (jobs pendentes/concluídos/falhados); taxa de erro.

Os serviços devem expor métricas Prometheus (endpoint `/metrics`) e anotações nos Pods/Services para o Prometheus fazer scrape. 
As métricas podem usar convenções como `http_requests_total`, `http_request_duration_seconds`, etc., para que os painéis funcionem com queries PromQL padrão.
