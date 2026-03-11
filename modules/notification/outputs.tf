###############################################################################
# Notificação — outputs
###############################################################################

output "sns_topic_arn" {
  description = "ARN of the SNS topic for video-processing-failed (publish from Videos worker)"
  value       = aws_sns_topic.video_failed.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.video_failed.name
}
