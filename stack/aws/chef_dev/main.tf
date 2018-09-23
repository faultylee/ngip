# single instance EC2 to test and develop chef provisioning without full infrastructure
provider "aws" {
  region = "ap-southeast-1"
}

data "terraform_remote_state" "jenkins" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "stack/jenkins/jenkins.tfstate"
    region = "ap-southeast-1"
  }
}

variable "git_sha_pretty" {
  default = "latest"
}
variable "local_public_ip" {}
variable "instance_type" {}
variable ecs_aws_ami {}

variable "ami_id_debian" {
  description = "Debian Stretch 9.5"
  default = "ami-0539351fee4a5a3b1"
}

variable "ami_id_al2" {
  description = "Amazon Linux 2"
  default = "ami-05868579"
}

variable "key_file" {
  description = "AWS Key File Name"
  default = "id_rsa_ngip"
}

locals {
  environment = "local"
  name_prefix = "ngip-chef-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key = "ssh/id_rsa_ngip"
}

data "aws_iam_policy_document" "ngip-ecr-readonly" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ngip-ecr-readonly" {
  name = "${local.name_prefix}-ecr-readonly"
  assume_role_policy = "${data.aws_iam_policy_document.ngip-ecr-readonly.json}"
}

resource "aws_iam_role_policy_attachment" "ngip-ecr-readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role = "${aws_iam_role.ngip-ecr-readonly.name}"
}

resource "aws_iam_instance_profile" "ngip-ecr-readonly-profile" {
  name = "${local.name_prefix}-ecr-readonly"
  role = "${aws_iam_role.ngip-ecr-readonly.name}"
}

########################
# EC2 Web
########################

resource "aws_security_group" "ngip-web" {
  name = "${local.name_prefix}-web"
  description = "Security group for ${local.name_prefix}-web"
  vpc_id = "${data.terraform_remote_state.jenkins.jenkins-vpc-id}"

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
      "${var.local_public_ip}/32",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = [
      "${var.local_public_ip}/32",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = [
      "${var.local_public_ip}/32",
      "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "${var.local_public_ip}/32",
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
  count = "1"
  ami = "${var.ami_id_al2}"
  instance_type = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web"
  }

  key_name = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id = "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-id}"

  iam_instance_profile = "${aws_iam_role.ngip-ecr-readonly.id}"

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
      "cd ~/cookbooks",
      "sudo chef-client -z -r middleware::default",
      "sudo $(sudo docker run --rm -i -e AWS_DEFAULT_REGION=ap-southeast-1 faultylee/aws-cli-docker:latest aws ecr get-login --no-include-email)",
      "sudo docker pull 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty}",
      #"sudo docker run --restart always -d -e POSTGRES_HOST=${var.POSTGRES_HOST} -e POSTGRES_PORT=5432 -e POSTGRES_DB=ngip -e POSTGRES_USER=ngip_user -e POSTGRES_PASSWORD=${var.POSTGRES_PASSWORD} -e REDIS_HOST=${var.REDIS_HOST} -e REDIS_PORT=6379 ADMIN_NAME=${var.ADMIN_NAME} -e ADMIN_EMAIL=${var.ADMIN_EMAIL} 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty} ./docker-entrypoint-celery-beat.sh",
      #"sudo docker run --restart always -d -e POSTGRES_HOST=${var.POSTGRES_HOST} -e POSTGRES_PORT=5432 -e POSTGRES_DB=ngip -e POSTGRES_USER=ngip_user -e POSTGRES_PASSWORD=${var.POSTGRES_PASSWORD} -e REDIS_HOST=${var.REDIS_HOST} -e REDIS_PORT=6379 ADMIN_NAME=${var.ADMIN_NAME} -e ADMIN_EMAIL=${var.ADMIN_EMAIL} 288211158144.dkr.ecr.ap-southeast-1.amazonaws.com/ngip/ngip-middleware-web:${var.git_sha_pretty} sh -c 'rm -f celeryev.pid && celery -A middleware events --camera django_celery_monitor.camera.Camera --frequency=2.0 --loglevel=info'"
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

output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.*.public_ip}"
}
