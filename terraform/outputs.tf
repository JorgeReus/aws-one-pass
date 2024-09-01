output "login_url" {
  description = "Custom Login URL"
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${var.aws_region}.amazoncognito.com/oauth2/authorize?response_type=token&client_id=${aws_cognito_user_pool_client.this.id}&redirect_uri=http://localhost:9000"
}

output "api_url" {
  description = "API URL"
  value       = "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}
