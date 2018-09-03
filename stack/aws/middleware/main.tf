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
  environment = "${data.terraform_remote_state.shared.environment != "" ? data.terraform_remote_state.shared.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key    = "ssh/id_rsa_ngip"
}

########################
# EC2 Web
########################

resource "aws_security_group" "ngip-web" {
  name        = "${local.name_prefix}-web"
  description = "Security group for ${local.name_prefix}-web"
  vpc_id      = "${data.terraform_remote_state.shared.ngip-vpc-id}"

  tags {
    Environment   = "${local.name_prefix}"
//    Cluster       = "${var.cluster}"
//    InstanceGroup = "${var.instance_group}"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
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
  count           = "${local.is_prod? length(data.terraform_remote_state.shared.ngip-availability-zones) : 1}"
  ami             = "${var.ami_id_al2}"
  instance_type   = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web-${element(data.terraform_remote_state.shared.ngip-availability-zones, count.index)}"
  }

  key_name        = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id       = "${element(data.terraform_remote_state.shared.ngip-subnet-pub-id, count.index)}"

  iam_instance_profile = "${data.terraform_remote_state.shared.ngip-ecr-readonly-id}"

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

output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.*.public_ip}"
}
