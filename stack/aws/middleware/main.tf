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
  description = "Security group for ngip-web"
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
