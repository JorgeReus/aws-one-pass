module "lambda_function" {
  source             = "terraform-aws-modules/lambda/aws"
  function_name      = "AwsOnePassSecretsFunction"
  description        = "Function to manage all password and secrets using parameter store (aws-one-pass)."
  handler            = "handler.handler"
  runtime            = "python3.12"
  memory_size        = 128
  timeout            = 30
  architectures      = ["arm64"]
  attach_policy_json = true
  policy_json        = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "ssm:PutParameter",
              "ssm:AddTagsToResource",
              "ssm:GetParameters",
              "ssm:GetParameter",
              "ssm:DescribeParameters",
              "ssm:ListTagsForResource"
            ],
            "Resource": "*"
        }
    ]
}
EOT
  source_path        = "../src/SecretsFunction/"

  tags = {
    Name = "AwsOnePassSecretsFunction"
  }
}

resource "aws_lambda_permission" "invoke_apigw" {
  statement_id  = "AllowInvokeApiGW"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_function.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*"
}

resource "aws_cognito_user_pool" "this" {
  name = "AwsOnePass"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  alias_attributes = ["email", "preferred_username"]

  auto_verified_attributes = ["email"]

  tags = {
    Name = "AwsOnePass"
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name                                 = "AwsOnePass"
  user_pool_id                         = aws_cognito_user_pool.this.id
  generate_secret                      = false
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  callback_urls                        = ["http://localhost:9000", "http://localhost:9200"]
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["openid", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows_user_pool_client = true
  supported_identity_providers         = ["COGNITO"]
}

resource "aws_cognito_user_pool_ui_customization" "this" {
  user_pool_id = aws_cognito_user_pool.this.id
  client_id    = aws_cognito_user_pool_client.this.id
  css          = <<CSS
.banner-customizable {
  background: linear-gradient(135deg, #e09711 0%, #411329 100%);
  background-image: url("https://asset.awslearn.cloud/one-pass.png");
  background-size: cover;
  background-position: center;
  background-repeat: no-repeat;
  height: 110px;
}
CSS

  depends_on = [aws_cognito_user_pool_domain.this]
}

resource "aws_cognito_user_pool_domain" "this" {
  domain       = "one-pass-reus"
  user_pool_id = aws_cognito_user_pool.this.id
}

resource "aws_api_gateway_rest_api" "this" {
  name = "AwsOnePassApi"
  body = jsonencode({
    openapi = "3.0"
    info = {
      version = "0.0.1"
      title   = "AWS One Pass API"
    }
    paths = {
      "/secrets" = {
        "post" = {
          "security" = [{
            "CognitoAuthorizer" = []
          }]
          "x-amazon-apigateway-integration" = {
            "httpMethod" = "POST"
            "type"       = "aws_proxy"
            "uri"        = "arn:${var.aws_partition}:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${module.lambda_function.lambda_function_arn}/invocations"
          }
          "responses" = {}
        }
        "put" = {
          "security" = [{
            "CognitoAuthorizer" = []
          }]
          "x-amazon-apigateway-integration" = {
            "httpMethod" = "POST"
            "type"       = "aws_proxy"
            "uri"        = "arn:${var.aws_partition}:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${module.lambda_function.lambda_function_arn}/invocations"
          }
          "responses" = {}
        }
        "get" = {
          "security" = [{
            "CognitoAuthorizer" = []
          }]
          "x-amazon-apigateway-integration" = {
            "httpMethod" = "POST"
            "type"       = "aws_proxy"
            "uri"        = "arn:${var.aws_partition}:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${module.lambda_function.lambda_function_arn}/invocations"
          }
          "responses" = {}
        }
      }
    }
  })
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "prod"
}

resource "aws_api_gateway_authorizer" "this" {
  name            = "CognitoAuthorizer"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [aws_cognito_user_pool.this.arn]
  identity_source = "method.request.header.Authorization"
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.this.body))
  }
}
