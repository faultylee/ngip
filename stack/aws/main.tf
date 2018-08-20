provider "aws" {
  region      = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "ngip-terraform.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}

variable "environment" {}
variable "vpc_cidr" {}
variable "max_size" {}
variable "min_size" {}
variable "desired_capacity" {}
variable "instance_type" {}
variable "az_index" {}
variable "public_subnet_cidrs" {
  type = "list"
}
variable "availability_zones" {
  type = "list"
}

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

variable "vpc_jenkins" {
  description = "VPC for Jenkins"
  default     = "vpc-0cb53cc89b0589890"
}

variable "subnet_pub_jenkins" {
  description = "Public Subnet: Jenkins"
  default     = "subnet-086734b335d13fc00"
}

variable "subnet_pub_jenkins_route" {
  description = "Route Table of Public Subnet: Jenkins"
  default     = "rtb-04ffac265e4850ec2"
}

variable "subnet_pub_jenkins_cidr" {
  description = "Cidr of Public Subnet: Jenkins"
  default     = "192.168.98.0/24"
}

variable "key_file" {
  description = "AWS Key File Name"
  default     = "id_rsa_ngip"
}

locals {
  environment = "${var.environment != "" ? var.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key    = "id_rsa_ngip"
}

resource "aws_vpc" "ngip-vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name        = "${local.name_prefix}"
    Environment = "${local.name_prefix}"
  }
}

resource "aws_internet_gateway" "ngip-vpc" {
  vpc_id = "${aws_vpc.ngip-vpc.id}"

  tags {
    Environment = "${local.name_prefix}"
  }
}

resource "aws_subnet" "ngip-subnet-pub" {
  vpc_id            = "${aws_vpc.ngip-vpc.id}"
  cidr_block        = "${element(var.public_subnet_cidrs, var.az_index)}"
  availability_zone = "${element(var.availability_zones, var.az_index)}"
  count             = 1

  tags {
    Name        = "${local.name_prefix}-pub-${element(var.availability_zones, var.az_index)}"
    Environment = "${local.name_prefix}"
  }
}

resource "aws_route_table" "ngip-subnet-pub" {
  vpc_id = "${aws_vpc.ngip-vpc.id}"
  count  = 1

  tags {
    Name        = "${local.name_prefix}-pub-${element(var.availability_zones, var.az_index)}"
    Environment = "${local.name_prefix}"
  }
}

resource "aws_route_table_association" "subnet" {
  subnet_id      = "${aws_subnet.ngip-subnet-pub.id}"
  route_table_id = "${aws_route_table.ngip-subnet-pub.id}"
  count          = 1
}

resource "aws_route" "public_igw_route" {
  count                  = 1
  route_table_id         = "${aws_route_table.ngip-subnet-pub.id}"
  gateway_id             = "${aws_internet_gateway.ngip-vpc.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_vpc_peering_connection" "jenkins_peering" {
  peer_vpc_id   = "${aws_vpc.ngip-vpc.id}"
  vpc_id        = "${var.vpc_jenkins}"
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = false
  }

  requester {
    allow_remote_vpc_dns_resolution = false
  }
}

resource "aws_route" "jenkins_peering_route" {
  route_table_id         = "${var.subnet_pub_jenkins_route}"
  gateway_id             = "${aws_vpc_peering_connection.jenkins_peering.id}"
  destination_cidr_block = "${aws_subnet.ngip-subnet-pub.cidr_block}"
}

resource "aws_route" "ngip_peering_route" {
  route_table_id         = "${aws_route_table.ngip-subnet-pub.id}"
  gateway_id             = "${aws_vpc_peering_connection.jenkins_peering.id}"
  destination_cidr_block = "${var.subnet_pub_jenkins_cidr}"
}

resource "aws_security_group" "ngip-web" {
  name        = "${local.environment}-ngip-web"
  description = "Security group for ngip-web"
  vpc_id      = "${aws_vpc.ngip-vpc.id}"

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
  ami             = "${var.ami_id_al2}"
  instance_type   = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web-${count.index}"
  }

  key_name        = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id       = "${aws_subnet.ngip-subnet-pub.id}"

  vpc_security_group_ids = ["${aws_security_group.ngip-web.id}"]

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
      "#sudo chef-solo -c chef/solo.rb -o example_app"
    ]
  }
}

output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.public_ip}"
}