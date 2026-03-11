###############################################################################
# Notificação (SNS + Lambda + SES) — erro de processamento de vídeo
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

variable "ses_sender_email" {
  description = "Verified SES sender email (identity must be verified in SES; in sandbox, recipient emails must also be verified)"
  type        = string
}

variable "email_subject" {
  description = "Subject line for the failure notification email"
  type        = string
  default     = "FiapX Videos — Erro no processamento do seu vídeo"
}
