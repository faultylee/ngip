provider "aws" {
  region      = "${data.terraform_remote_state.shared.aws_region}"
}

data "terraform_remote_state" "jenkins" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "stack/jenkins/jenkins.tfstate"
    region = "ap-southeast-1"
  }
}

variable "git_sha_pretty" { default = "latest" }

locals {
  environment = "${data.terraform_remote_state.shared.environment != "" ? data.terraform_remote_state.shared.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

########################
# Lambda
########################

resource "aws_iam_role" "ngip-ping-assume-role" {
  name = "${local.name_prefix}-ping-assume-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

//resource "aws_iam_role_policy_attachment" "ngip-ping-policy" {
//  role       = "${aws_iam_role.ngip-ping-assume-role.name}"
//  policy_arn = "${aws_iam_policy.ngip-ping-policy.arn}"
//  // Need this otherwise
//  depends_on = [
//    "aws_lambda_function.ngip-ping",
//    "aws_iam_policy.ngip-ping-policy"
//  ]
//}

resource "aws_iam_role_policy" "ngip-ping-policy" {
  name = "${local.name_prefix}-ping-role"
  role = "${aws_iam_role.ngip-ping-assume-role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_security_group" "ngip-ping" {
  name        = "${local.name_prefix}-ping"
  description = "Security group for ${local.name_prefix}-ping"
  vpc_id      = "${data.terraform_remote_state.shared.ngip-vpc-id}"

  tags {
    Environment   = "${local.name_prefix}"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lambda_function" "ngip-ping" {
  function_name = "${local.name_prefix}-ping"

  depends_on = [
    "aws_iam_role_policy.ngip-ping-policy"
  ]

  # The bucket name as created earlier with "aws s3api create-bucket"
  s3_bucket = "ngip-private"
  s3_key    = "ngip-ping/lambda-function-${var.git_sha_pretty}.zip"

  # "main" is the filename within the zip file (main.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "service.handler"
  runtime = "python3.6"

  environment {
    variables {
      REDIS_DB = "0"
      REDIS_HOST = "${data.terraform_remote_state.shared.ngip-redis-address}"
    }
  }

  role = "${aws_iam_role.ngip-ping-assume-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.ngip-ping.id}"]
    subnet_ids = ["${data.terraform_remote_state.shared.ngip-subnet-pub-id}"]
  }
}

resource "aws_api_gateway_rest_api" "ngip-ping" {
  name        = "${local.name_prefix}-ping"
  description = "Lambda for ${local.name_prefix}-ping"
}

resource "aws_api_gateway_resource" "ngip-ping-subpath" {
  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  parent_id   = "${aws_api_gateway_resource.ngip-ping-path.id}"
  path_part   = "{pingToken}"
}

resource "aws_api_gateway_method" "ngip-ping-subpath" {
  rest_api_id   = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id   = "${aws_api_gateway_resource.ngip-ping-subpath.id}"
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters {
    "method.request.path.pingToken" = true
  }
}

//resource "aws_api_gateway_method_response" "200" {
//  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
//  resource_id = "${aws_api_gateway_resource.ngip-ping-subpath.id}"
//  http_method = "${aws_api_gateway_method.ngip-ping-subpath.http_method}"
//  status_code = "200"
//  response_models {
//    "application/json" = "Empty"
//  }
//}

resource "aws_api_gateway_integration" "ngip-ping-subpath" {
  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id = "${aws_api_gateway_method.ngip-ping-subpath.resource_id}"
  http_method = "${aws_api_gateway_method.ngip-ping-subpath.http_method}"

  content_handling = "CONVERT_TO_TEXT"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.ngip-ping.invoke_arn}"

}

//resource "aws_api_gateway_integration_response" "ngip-ping-subpath" {
//  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
//  resource_id = "${aws_api_gateway_resource.ngip-ping-subpath.id}"
//  http_method = "${aws_api_gateway_method.ngip-ping-subpath.http_method}"
//  status_code = "${aws_api_gateway_method_response.200.status_code}"
//}

resource "aws_api_gateway_resource" "ngip-ping-path" {
  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  parent_id   = "${aws_api_gateway_rest_api.ngip-ping.root_resource_id}"
//  path_part   = "{ping}"
  path_part   = "ping"
}

resource "aws_api_gateway_method" "ngip-ping-path" {
  rest_api_id   = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id   = "${aws_api_gateway_resource.ngip-ping-path.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "ngip-ping-path" {
  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id = "${aws_api_gateway_method.ngip-ping-path.resource_id}"
  http_method = "${aws_api_gateway_method.ngip-ping-path.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.ngip-ping.invoke_arn}"

}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id   = "${aws_api_gateway_rest_api.ngip-ping.root_resource_id}"
  http_method   = "GET"
  authorization = "NONE"
}


resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  resource_id = "${aws_api_gateway_rest_api.ngip-ping.root_resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.ngip-ping.invoke_arn}"
}

resource "aws_api_gateway_deployment" "ngip-ping" {
  depends_on = [
    "aws_api_gateway_integration.ngip-ping-path",
    "aws_api_gateway_integration.ngip-ping-subpath",
    "aws_api_gateway_integration.lambda_root",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.ngip-ping.id}"
  stage_name  = "default"
}

resource "aws_lambda_permission" "apigw" {
  //statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ngip-ping.arn}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.ngip-ping.execution_arn}/*/*"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.ngip-ping.invoke_url}"
}