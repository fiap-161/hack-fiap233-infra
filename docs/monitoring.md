# Monitoramento — Prometheus + Grafana (Fase 5)

Stack de observabilidade no repositório da infra: **Prometheus** e **Grafana** no namespace `monitoring`, provisionados via Terraform + Helm.

## Onde está o código

- **Prometheus:** [modules/prometheus/](../modules/prometheus/) — Helm chart [prometheus-community/prometheus](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus).
- **Grafana:** [modules/grafana/](../modules/grafana/) — Helm chart [grafana/grafana](https://github.com/grafana/helm-charts/tree/main/charts/grafana); datasource Prometheus pré-configurado; credenciais admin em Secret.
- **Dashboards (código):** [monitoring/grafana-dashboards/](../monitoring/grafana-dashboards/) — lugar para JSONs de dashboards (Users, Videos).
- **Variáveis:** `variables.tf` (prefixos `prometheus_*`, `grafana_*`).
- **Outputs:** `prometheus_namespace`, `prometheus_url`, `grafana_namespace`, `grafana_url`, `grafana_admin_secret_name`.

## Como aplicar

O Prometheus é provisionado junto com o restante da infra:

```bash
cd hack-fiap233-infra
terraform init
terraform apply -auto-approve
```

Ou use o script de setup:

```bash
./scripts/setup_infra.sh
```

## Acesso ao Prometheus

O Prometheus fica apenas **dentro do cluster** (Service tipo ClusterIP). Para acessar em dev/demo:

```bash
kubectl port-forward -n monitoring svc/prometheus-server 9090:80
```

Depois abra no navegador: **http://localhost:9090**

- **URL interna (para Grafana ou outros pods):** `http://prometheus-server.monitoring.svc.cluster.local:80`  
  (o chart expõe a UI na porta 80 do Service, redirecionando para a porta 9090 do container.)

## Descoberta de métricas (scrape)

O chart já inclui scrape configs que descobrem:

- **Pods** com anotações:
  - `prometheus.io/scrape: "true"`
  - `prometheus.io/port: "8080"` (ou a porta do endpoint de métricas)
  - `prometheus.io/path: "/metrics"` (opcional; default é `/metrics`)
- **Services** com as mesmas anotações nos *Services* (não só nos Pods).

Os serviços **Users** e **Videos** devem:

1. Expor um endpoint de métricas no formato Prometheus (ex.: `GET /metrics`).
2. Nos manifests K8s (Deployment e/ou Service), adicionar as anotações acima no template do Pod ou no Service.

Exemplo no Deployment dos serviços:

```yaml
template:
  metadata:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "8080"
      prometheus.io/path: "/metrics"
```

## Persistência e recursos

- **Persistência:** habilitada (PVC), tamanho configurável via `prometheus_storage_size` (default `8Gi`). StorageClass usa o default do cluster (EKS: normalmente `gp2`/`gp3`); opcionalmente defina `prometheus_storage_class`.
- **Recursos:** requests/limits definidos no módulo para não disputar com as aplicações (requests: 100m CPU, 512Mi RAM; limits: 1 CPU, 1Gi RAM).
- **Retenção:** `prometheus_retention` (default `15d`).

## Variáveis (resumo)

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `prometheus_namespace` | `monitoring` | Namespace do Prometheus |
| `prometheus_helm_chart_version` | `27.0.0` | Versão do chart Helm |
| `prometheus_retention` | `15d` | Retenção das métricas |
| `prometheus_storage_size` | `8Gi` | Tamanho do PVC |
| `prometheus_storage_class` | `null` | StorageClass (null = default do cluster) |

---

## Grafana

### Deploy

O Grafana sobe junto com o `terraform apply`, no mesmo namespace `monitoring`. O datasource **Prometheus** é configurado automaticamente (URL interna do Prometheus). As credenciais de admin ficam em um Secret (não usar usuário/senha default em produção).

### Acesso em dev/demo

```bash
kubectl port-forward -n monitoring svc/grafana 3000:80
```

Abra no navegador: **http://localhost:3000**

- **Usuário:** por padrão `admin` (variável `grafana_admin_user`).
- **Senha:** gerada pelo Terraform e armazenada no Secret. Para obter:
  ```bash
  kubectl get secret -n monitoring grafana-admin-credentials -o jsonpath='{.data.admin-password}' | base64 -d
  echo
  ```
  (O nome do secret pode ser obtido com `terraform output grafana_admin_secret_name`.)

### Persistência e recursos

- **Persistência:** habilitada (PVC), tamanho configurável via `grafana_storage_size` (default `2Gi`).
- **Recursos:** requests/limits definidos no módulo (100m–500m CPU, 256Mi–512Mi RAM).

### Variáveis Grafana (resumo)

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `grafana_helm_chart_version` | `8.3.3` | Versão do chart Helm |
| `grafana_storage_size` | `2Gi` | Tamanho do PVC |
| `grafana_storage_class` | `null` | StorageClass (null = default do cluster) |
| `grafana_admin_user` | `admin` | Usuário admin do Grafana |

### Dashboards

- Dashboards para **Users** e **Videos** (latência, erros, throughput) podem ser definidos como JSON em [monitoring/grafana-dashboards/](../monitoring/grafana-dashboards/) e importados manualmente ou via sidecar (ver README da pasta).
