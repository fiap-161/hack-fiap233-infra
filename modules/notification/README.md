# Notification (SNS + Lambda + SendGrid)

SNS topic + Lambda envia e-mail via SendGrid ao `user_email` do payload. 
Variáveis: `sender_email` (verificado no SendGrid), `sender_name`, `sendgrid_api_key`, `email_subject`.

- **Produção:** valores via GitHub Secrets; workflow `terraform.yml` injeta como `TF_VAR_*`.
- **Teste local:** passar via `terraform.tfvars` ou `export TF_VAR_*`. Ver [README principal — Notificação](../../README.md#notificação-em-caso-de-erro-sns--lambda--sendgrid).
