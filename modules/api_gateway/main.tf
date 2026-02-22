###############################################################################
# HTTP API (API Gateway v2)
###############################################################################

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  tags = {
    Name = "${var.project_name}-api"
  }
}

###############################################################################
# VPC Link
###############################################################################

resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "${var.project_name}-vpc-link"
  subnet_ids         = var.subnet_ids
  security_group_ids = var.security_group_ids

  tags = {
    Name = "${var.project_name}-vpc-link"
  }
}

###############################################################################
# Integrations
###############################################################################

resource "aws_apigatewayv2_integration" "users" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.nlb_listener_users_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

resource "aws_apigatewayv2_integration" "videos" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = var.nlb_listener_videos_arn
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id
}

###############################################################################
# Routes
###############################################################################

resource "aws_apigatewayv2_route" "users" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /users/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.users.id}"
}

resource "aws_apigatewayv2_route" "videos" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /videos/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.videos.id}"
}

###############################################################################
# Stage (auto-deploy)
###############################################################################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "${var.project_name}-api-default-stage"
  }
}
