provider "aws" {
  region      = "ap-southeast-1"
}

data "terraform_remote_state" "jenkins" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "jenkins.tfstate"
    region = "ap-southeast-1"
  }
}

variable "aws_region" { default = "ap-southeast-1" }
variable "git_sha_pretty" { default = "latest" }
variable "environment" {}
variable "max_size" {}
variable "min_size" {}
variable "desired_capacity" {}
variable "instance_type" {}

variable "ami_id_debian" {
  description = "Debian Stretch 9.5"
  default     = "ami-0539351fee4a5a3b1"
}

variable "ami_id_al2" {
  description = "Amazon Linux 2"
  default     = "ami-05868579"
}

variable "ami_id_ecs" {
  description = "amzn-ami-2018.03.e-amazon-ecs-optimized"
  default     = "ami-091bf462afdb02c60"
}

variable "key_file" {
  description = "AWS Key File Name"
  default     = "id_rsa_ngip"
}

locals {
  environment = "${var.environment != "" ? var.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key    = "id_rsa_ngip"
}

########################
# ELB
########################

//resource "aws_elb" "this" {
//  name            = "${local.name_prefix}"
//  subnets         = ["${var.public_subnet_cidrs}"]
//  internal        = false
//  security_groups = ["${var.security_groups}"]
//
//  cross_zone_load_balancing   = true
//  idle_timeout                = "${var.idle_timeout}"
//  connection_draining         = "${var.connection_draining}"
//  connection_draining_timeout = "${var.connection_draining_timeout}"
//
//  listener     = ["${var.listener}"]
//  access_logs  = ["${var.access_logs}"]
//  health_check = ["${var.health_check}"]
//
//  lifecycle { create_before_destroy = "${local.is_prod ? true : false}" }
//
//  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
//}

########################
# EC2 Web
########################

resource "aws_security_group" "ngip-web" {
  name        = "${local.name_prefix}-web"
  description = "Security group for ${local.name_prefix}-web"
  vpc_id      = "${data.terraform_remote_state.base.ngip-vpc-id}"

  tags {
    Environment   = "${local.name_prefix}"
//    Cluster       = "${var.cluster}"
//    InstanceGroup = "${var.instance_group}"
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

resource "aws_instance" "ngip-web" {
  count           = "${local.is_prod? length(data.terraform_remote_state.base.ngip-availability-zones) : 1}"
  ami             = "${var.ami_id_al2}"
  instance_type   = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web-${element(data.terraform_remote_state.base.ngip-availability-zones, count.index)}"
  }

  key_name        = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id       = "${element(data.terraform_remote_state.base.ngip-subnet-pub-id, count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.base.ngip-ecr-readonly-id}"

  vpc_security_group_ids = ["${aws_security_group.ngip-web.id}"]

}

resource "null_resource" remote-exec-chef-cookbooks {
  depends_on = ["null_resource.local-exec-copy-chef-cookbooks"]
  provisioner "remote-exec" {
    connection {
      host        = "${local.environment == "local" ? aws_instance.ngip-web.public_ip : aws_instance.ngip-web.private_ip}"
      type        = "ssh"
      user        = "ec2-user"
      //user        = "admin"
      private_key = "${data.aws_s3_bucket_object.key_file.body}"
      agent       = false
      timeout     = "2m"
    }

    inline = [
      "sudo yum check-update",
      "sudo yum -y update",
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash",
      "chef-client --version",
      "cd ~/cookbooks",
      "sudo chef-solo -c solo.rb -o test::default",
      "sudo $(sudo docker run --rm -i -e AWS_DEFAULT_REGION=ap-southeast-1 faultylee/aws-cli-docker:latest aws ecr get-login --no-include-email)",
      "sudo docker pull 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty}"
      //"sudo docker run --rm -it -e POSTGRES_HOST=stage-ngip-db.cjdsty76imhp.ap-southeast-1.rds.amazonaws.com -e POSTGRES_PORT=5432 -e POSTGRES_DB=ngip -e POSTGRES_USER=ngip_user -e POSTGRES_PASSWORD=ngip_user -e REDIS_PASSWORD=redisPassword123 -e REDIS_HOST=ngip-local-rep-1-001.ngip-local-rep-1.cuyq10.apse1.cache.amazonaws.com -e REDIS_PORT=6379 -e MQTT_HOST=localhost -e MQTT_PORT=1883 -e ADMIN_NAME=faulty -e ADMIN_EMAIL=faulty.lee@gmail.com -p 8000:8000 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:9477153 python manage.py runserver 0.0.0.0:8000"
    ]
  }
}

resource "null_resource" local-exec-copy-chef-cookbooks {

  provisioner "file" {
    // Upload cookbooks to /home/ec2-user/cookbooks
    source = "/cookbooks"
    destination = "/home/ec2-user/"
  }

  connection {
    host        = "${local.environment == "local" ? aws_instance.ngip-web.public_ip : aws_instance.ngip-web.private_ip}"
    type        = "ssh"
    user        = "ec2-user"
    //user        = "admin"
    private_key = "${data.aws_s3_bucket_object.key_file.body}"
    agent       = false
    timeout     = "2m"
  }
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

resource "aws_iam_role_policy_attachment" "ngip-ping-policy" {
  role       = "${aws_iam_role.ngip-ping-assume-role.name}"
  policy_arn = "${aws_iam_policy.ngip-ping-policy.arn}"
}

resource "aws_iam_policy" "ngip-ping-policy" {
  name = "${local.name_prefix}-ping-role"

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
  vpc_id      = "${data.terraform_remote_state.base.ngip-vpc-id}"

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

  # The bucket name as created earlier with "aws s3api create-bucket"
  s3_bucket = "ngip-private"
  s3_key    = "ngip-ping/lambda-function.zip"

  # "main" is the filename within the zip file (main.js) and "handler"
  # is the name of the property under which the handler function was
  # exported in that file.
  handler = "service.handler"
  runtime = "python3.6"

  environment {
    variables {
      REDIS_DB = "0"
      REDIS_HOST = "${data.terraform_remote_state.base.ngip-redis-address}"
    }
  }

  role = "${aws_iam_role.ngip-ping-assume-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.ngip-ping.id}"]
    subnet_ids = ["${data.terraform_remote_state.base.ngip-subnet-pub-id}"]
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

//resource "aws_lambda_permission" "apigw-sub" {
//  //statement_id  = "AllowExecutionFromAPIGateway"
//  action        = "lambda:InvokeFunction"
//  function_name = "${aws_lambda_function.ngip-ping.arn}"
//  principal     = "apigateway.amazonaws.com"
//
//  # The /*/* portion grants access from any method on any resource
//  # within the API Gateway "REST API".
//  source_arn = "${aws_api_gateway_rest_api.ngip-ping.execution_arn}/*/*/ping/*"
//}

########################
# RDS - Postgres
########################

//resource "aws_cloudwatch_log_group" "ngip-db" {
//  name = "${local.name_prefix}-db"
//  retention_in_days = "${local.is_prod ? 45 : 1}"
//  tags {
//    Environment   = "${local.name_prefix}"
//  }
//
//}

output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.*.public_ip}"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.ngip-ping.invoke_url}"
}