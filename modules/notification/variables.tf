###############################################################################
# Notificação (SNS + Lambda + SendGrid) — erro de processamento de vídeo
###############################################################################

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "topic_name" {
  description = "SNS topic name for video processing failure events"
  type        = string
  default     = "video-processing-failed"
}

variable "sender_email" {
  description = "Sender email (From). Must be verified in SendGrid Single Sender Verification."
  type        = string
}

variable "sender_name" {
  description = "Sender display name (e.g. FiapX Videos)"
  type        = string
  default     = "FiapX Videos"
}

variable "sendgrid_api_key" {
  description = "SendGrid API key (Mail Send permission). Prefer passing via TF_VAR or -var."
  type        = string
  sensitive   = true
}

variable "email_subject" {
  description = "Subject line for the failure notification email"
  type        = string
  default     = "FiapX Videos — Erro no processamento do seu vídeo"
}
