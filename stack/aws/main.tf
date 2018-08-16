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

variable "ami_id" {
  //description = "Amazon Linux 2"
  //default = "ami-05868579"
  description = "Debian Stretch 9.5"
  default = "ami-0539351fee4a5a3b1"
}

variable "vpc_jenkins" {
  description = "VPC for Jenkins"
  default = "vpc-0cb53cc89b0589890"
}

variable "subnet_pub_jenkins" {
  description = "Public Subnet: Jenkins"
  default = "subnet-086734b335d13fc00"
}

variable "key_file" {
  description = "AWS Key File Name"
  default = "id_rsa_aws_jenkins"
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key    = "id_rsa_aws_jenkins"
}

resource "aws_security_group" "ngip-web" {
  name = "ngip-web"
  description = "Security group for ngip-web"
  vpc_id = "${var.vpc_jenkins}"
  ingress {
    from_port = 8000
    to_port = 8000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ngip-web" {
  ami             = "${var.ami_id}"
  instance_type   = "t2.micro"
  tags {
    Name = "ngip-web"
  }

  key_name        = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id       = "${var.subnet_pub_jenkins}"

  vpc_security_group_ids = ["${aws_security_group.ngip-web.id}"]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      //user        = "ec2-user"
      user        = "admin"
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

