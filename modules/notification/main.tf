###########################################################################
# SNS Topic — eventos de falha no processamento de vídeo
###########################################################################

resource "aws_sns_topic" "video_failed" {
  name = "${var.project_name}-${var.topic_name}"

  tags = {
    Name = "${var.project_name}-${var.topic_name}"
  }
}

##########################################################################
# Lambda — envia e-mail via SES (template HTML)
##########################################################################

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.js"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "video_failed_notify" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.project_name}-video-failed-notify"
  role             = aws_iam_role.lambda_ses.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 30

  environment {
    variables = {
      SES_SENDER_EMAIL = var.ses_sender_email
      EMAIL_SUBJECT    = var.email_subject
    }
  }

  tags = {
    Name = "${var.project_name}-video-failed-notify"
  }
}

###############################################################################
# Permissão SNS -> invocar Lambda
###############################################################################

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.video_failed_notify.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.video_failed.arn
}

###############################################################################
# Inscrição SNS -> Lambda
###############################################################################

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.video_failed.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.video_failed_notify.arn
}

###############################################################################
# SES — identidade do remetente (e-mail a ser verificado no SES)
###############################################################################

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

###############################################################################
# IAM — Lambda pode enviar e-mail via SES
###############################################################################

resource "aws_iam_role" "lambda_ses" {
  name = "${var.project_name}-video-failed-notify-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_ses" {
  name   = "ses-send-email"
  role   = aws_iam_role.lambda_ses.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}
