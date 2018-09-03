provider "aws" {
  region = "${data.terraform_remote_state.shared.aws_region}"
}

data "terraform_remote_state" "jenkins" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key = "stack/jenkins/jenkins.tfstate"
    region = "ap-southeast-1"
  }
}

variable "git_sha_pretty" {
  default = "latest"
}
variable "max_size" {}
variable "min_size" {}
variable "desired_capacity" {}
variable "instance_type" {}
variable ecs_aws_ami {}
variable SECRET_KEY {}
variable POSTGRES_HOST {}
variable POSTGRES_PASSWORD {}
variable REDIS_HOST {}
variable ADMIN_NAME {}
variable ADMIN_EMAIL {}
variable AWS_DEFAULT_REGION {}
variable AWS_NGIP_ACCESS_KEY_ID {}
variable AWS_NGIP_SECRET_ACCESS_KEY {}

variable "ami_id_debian" {
  description = "Debian Stretch 9.5"
  default = "ami-0539351fee4a5a3b1"
}

variable "ami_id_al2" {
  description = "Amazon Linux 2"
  default = "ami-05868579"
}

variable "ami_id_ecs" {
  description = "amzn-ami-2018.03.e-amazon-ecs-optimized"
  default = "ami-091bf462afdb02c60"
}

variable "key_file" {
  description = "AWS Key File Name"
  default = "id_rsa_ngip"
}

locals {
  environment = "${data.terraform_remote_state.shared.environment != "" ? data.terraform_remote_state.shared.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key = "ssh/id_rsa_ngip"
}

########################
# EC2 Web
########################

resource "aws_security_group" "ngip-web" {
  name = "${local.name_prefix}-web"
  description = "Security group for ${local.name_prefix}-web"
  vpc_id = "${data.terraform_remote_state.shared.ngip-vpc-id}"

  tags {
    Environment = "${local.name_prefix}"
    //    Cluster       = "${var.cluster}"
    //    InstanceGroup = "${var.instance_group}"
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = [
      "${data.terraform_remote_state.shared.ngip-subnet-pub-cidr}",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = [
      "${data.terraform_remote_state.shared.ngip-subnet-pub-cidr}",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = [
      "${data.terraform_remote_state.shared.ngip-subnet-pub-cidr}",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "${data.terraform_remote_state.shared.ngip-subnet-pub-cidr}",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

resource "aws_instance" "ngip-web" {
  count = "${local.is_prod? length(data.terraform_remote_state.shared.ngip-availability-zones) : 1}"
  ami = "${var.ami_id_al2}"
  instance_type = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web-${element(data.terraform_remote_state.shared.ngip-availability-zones, count.index)}"
  }

  key_name = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id = "${element(data.terraform_remote_state.shared.ngip-subnet-pub-id, count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.shared.ngip-ecr-readonly-id}"

  vpc_security_group_ids = [
    "${aws_security_group.ngip-web.id}"]

}

resource "null_resource" remote-exec-chef-cookbooks {
  depends_on = [
    "null_resource.local-exec-copy-chef-cookbooks"]
  provisioner "remote-exec" {
    connection {
      host = "${local.environment == "local" ? aws_instance.ngip-web.public_ip : aws_instance.ngip-web.private_ip}"
      type = "ssh"
      user = "ec2-user"
      //user        = "admin"
      private_key = "${data.aws_s3_bucket_object.key_file.body}"
      agent = false
      timeout = "2m"
    }

    inline = [
      "set -x",
      "sudo yum check-update",
      "sudo yum -y update",
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash",
      "chef-client --version",
      "cd ~/cookbooks",
      "sudo chef-solo -c solo.rb -o test::default",
      "sudo $(sudo docker run --rm -i -e AWS_DEFAULT_REGION=ap-southeast-1 faultylee/aws-cli-docker:latest aws ecr get-login --no-include-email)",
      "sudo docker pull 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty}",
      "sudo docker run --restart always -d -e POSTGRES_HOST=${var.POSTGRES_HOST} -e POSTGRES_PORT=5432 -e POSTGRES_DB=ngip -e POSTGRES_USER=ngip_user -e POSTGRES_PASSWORD=${var.POSTGRES_PASSWORD} -e REDIS_HOST=${var.REDIS_HOST} -e REDIS_PORT=6379 ADMIN_NAME=${var.ADMIN_NAME} -e ADMIN_EMAIL=${var.ADMIN_EMAIL} 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty} ./docker-entrypoint-celery-beat.sh",
      "sudo docker run --restart always -d -e POSTGRES_HOST=${var.POSTGRES_HOST} -e POSTGRES_PORT=5432 -e POSTGRES_DB=ngip -e POSTGRES_USER=ngip_user -e POSTGRES_PASSWORD=${var.POSTGRES_PASSWORD} -e REDIS_HOST=${var.REDIS_HOST} -e REDIS_PORT=6379 ADMIN_NAME=${var.ADMIN_NAME} -e ADMIN_EMAIL=${var.ADMIN_EMAIL} 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty} sh -c 'rm -f celeryev.pid && celery -A middleware events --camera django_celery_monitor.camera.Camera --frequency=2.0 --loglevel=info'"
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
    host = "${local.environment == "local" ? aws_instance.ngip-web.public_ip : aws_instance.ngip-web.private_ip}"
    type = "ssh"
    user = "ec2-user"
    //user        = "admin"
    private_key = "${data.aws_s3_bucket_object.key_file.body}"
    agent = false
    timeout = "2m"
  }
}

########################
# ECS Web ref: https://github.com/arminc/terraform-ecs/tree/master/modules/ecs_instances
########################
# future blue/green deployment ref: https://github.com/silinternational/ecs-deploy

resource "aws_ecs_cluster" "ngip-web-cluster" {
  name = "${local.name_prefix}-web-cluster"
}

# ref: https://github.com/otterley/ec2-autoscaling-lifecycle-helpers/blob/41ef9d777365330abe6da04a643cb3aac2b104ca/test/ecs_instance_drainer/infra.tf
# seems a bit too permissive
resource "aws_iam_role_policy" "ngip-web-ecs-policy" {
  name = "ecs_instance_role"
  role = "${aws_iam_role.ngip-web-ecs-role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:CreateCluster",
        "ecs:DeregisterContainerInstance",
        "ecs:DiscoverPollEndpoint",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecs:StartTask"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ngip-web-ecs-role" {
  name = "${local.environment}-ecs-instance-role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com"]
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ngip-web-asg" {
  name = "${local.name_prefix}-web"
  path = "/"
  role = "${aws_iam_role.ngip-web-ecs-role.name}"
}

resource "aws_launch_configuration" "ngip-web-asg" {
  name_prefix = "${local.name_prefix}-web"
  image_id = "${var.ecs_aws_ami}"
  instance_type = "${var.instance_type}"
  security_groups = [
    "${aws_security_group.ngip-web.id}"]
  #user_data            = "${data.template_file.user_data.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.ngip-web-asg.id}"
  key_name = "${var.key_file}"

  # TODO: disable when switching to NAT Gateway
  associate_public_ip_address = true

  user_data = "#!/bin/bash\necho ECS_CLUSTER='${aws_ecs_cluster.ngip-web-cluster.name}' > /etc/ecs/ecs.config"

  # aws_launch_configuration can not be modified.
  # Therefore we use create_before_destroy so that a new modified aws_launch_configuration can be created
  # before the old one get's destroyed. That's why we use name_prefix instead of name.
  lifecycle {
    create_before_destroy = true
  }
}

# Instances are scaled across availability zones http://docs.aws.amazon.com/autoscaling/latest/userguide/auto-scaling-benefits.html
resource "aws_autoscaling_group" "ngip-web-asg" {
  name = "${local.name_prefix}-web"
  max_size = "${var.max_size}"
  min_size = "${var.min_size}"
  desired_capacity = "${var.desired_capacity}"
  force_delete = true
  launch_configuration = "${aws_launch_configuration.ngip-web-asg.id}"
  vpc_zone_identifier = [
    "${data.terraform_remote_state.shared.ngip-subnet-pub-id}"]
  #load_balancers       = ["${data.terraform_remote_state.shared.ngip-elb-target-group-id}"]
  target_group_arns = [
    "${data.terraform_remote_state.shared.ngip-elb-target-group-id}"]

  tag {
    key = "Name"
    value = "${local.name_prefix}-asg"
    propagate_at_launch = "true"
  }

  tag {
    key = "Environment"
    value = "${local.environment}"
    propagate_at_launch = "true"
  }

  # EC2 instances require internet connectivity to boot. Thus EC2 instances must not start before NAT is available.
  # For info why see description in the network module.
  //  tag {
  //    key                 = "DependsId"
  //    value               = "${var.depends_id}"
  //    propagate_at_launch = "false"
  //  }
}

resource "aws_ecs_task_definition" "ngip-web-task" {
  family = "${local.name_prefix}-web"

  container_definitions = <<EOF
[
  {
    "name": "middleware-web",
    "image": "288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty}",
    "cpu": 512,
    "essential": true,
    "memory": 256,
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 8000,
        "protocol": "tcp"
      }
    ],
    "command": [
      "./docker-entrypoint-web.sh"
    ],
    "environment": [ {
      "name": "DJANGO_DEBUG",
      "value": "false"
      },
      {
        "name": "ENVIRONMENT",
        "value": "${local.environment}"
      },
      {
        "name": "SECRET_KEY",
        "value": "${var.SECRET_KEY}"
      },
      {
        "name": "POSTGRES_HOST",
        "value": "${var.POSTGRES_HOST}"
      },
      {
        "name": "POSTGRES_PORT",
        "value": "5432"
      },
      {
        "name": "POSTGRES_DB",
        "value": "ngip"
      },
      {
        "name": "POSTGRES_USER",
        "value": "ngip_user"
      },
      {
        "name": "POSTGRES_PASSWORD",
        "value": "${var.POSTGRES_PASSWORD}"
      },
      {
        "name": "REDIS_HOST",
        "value": "${var.REDIS_HOST}"
      },
      {
        "name": "REDIS_PORT",
        "value": "6379"
      },
      {
        "name": "REDIS_DB",
        "value": "0"
      },
      {
        "name": "REDIS_PASSWORD",
        "value": ""
      },
      {
        "name": "ADMIN_NAME",
        "value": "${var.ADMIN_NAME}"
      },
      {
        "name": "ADMIN_EMAIL",
        "value": "${var.ADMIN_EMAIL}"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "${var.AWS_DEFAULT_REGION}"
      },
      {
        "name": "AWS_NGIP_ACCESS_KEY_ID",
        "value": "${var.AWS_NGIP_ACCESS_KEY_ID}"
      },
      {
        "name": "AWS_NGIP_SECRET_ACCESS_KEY",
        "value": "${var.AWS_NGIP_SECRET_ACCESS_KEY}"
      }
    ]
  }
]
EOF
}

resource "aws_ecs_task_definition" "ngip-worker-task" {
  family = "${local.name_prefix}-worker"

  container_definitions = <<EOF
[
  {
    "name": "middleware-worker",
    "image": "288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty}",
    "cpu": 512,
    "essential": true,
    "memory": 256,
    "command": [
      "sh -c 'celery -E -A middleware worker --loglevel=info --concurrency=2 -n celery@$ENVIRONMENT'"
    ],
    "environment": [ {
        "name": "DJANGO_DEBUG",
        "value": "false"
      },
      {
        "name": "ENVIRONMENT",
        "value": "${local.environment}"
      },
      {
        "name": "SECRET_KEY",
        "value": "${var.SECRET_KEY}"
      },
      {
        "name": "POSTGRES_HOST",
        "value": "${var.POSTGRES_HOST}"
      },
      {
        "name": "POSTGRES_PORT",
        "value": "5432"
      },
      {
        "name": "POSTGRES_DB",
        "value": "ngip"
      },
      {
        "name": "POSTGRES_USER",
        "value": "ngip_user"
      },
      {
        "name": "POSTGRES_PASSWORD",
        "value": "${var.POSTGRES_PASSWORD}"
      },
      {
        "name": "REDIS_HOST",
        "value": "${var.REDIS_HOST}"
      },
      {
        "name": "REDIS_PORT",
        "value": "6379"
      },
      {
        "name": "REDIS_DB",
        "value": "0"
      },
      {
        "name": "REDIS_PASSWORD",
        "value": ""
      },
      {
        "name": "ADMIN_NAME",
        "value": "${var.ADMIN_NAME}"
      },
      {
        "name": "ADMIN_EMAIL",
        "value": "${var.ADMIN_EMAIL}"
      },
      {
        "name": "AWS_DEFAULT_REGION",
        "value": "${var.AWS_DEFAULT_REGION}"
      },
      {
        "name": "AWS_NGIP_ACCESS_KEY_ID",
        "value": "${var.AWS_NGIP_ACCESS_KEY_ID}"
      },
      {
        "name": "AWS_NGIP_SECRET_ACCESS_KEY",
        "value": "${var.AWS_NGIP_SECRET_ACCESS_KEY}"
      }
    ]
  }
]
EOF
}

resource "aws_ecs_service" "ngip-web-service" {
  name = "${local.name_prefix}-web-service"
  cluster = "${aws_ecs_cluster.ngip-web-cluster.id}"
  task_definition = "${aws_ecs_task_definition.ngip-web-task.arn}"
  desired_count = 1
  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 50
}

resource "aws_ecs_service" "ngip-worker-service" {
  name = "${local.name_prefix}-worker-service"
  cluster = "${aws_ecs_cluster.ngip-web-cluster.id}"
  task_definition = "${aws_ecs_task_definition.ngip-worker-task.arn}"
  desired_count = 1
  deployment_maximum_percent = 100
  deployment_minimum_healthy_percent = 50
}


output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.*.public_ip}"
}
