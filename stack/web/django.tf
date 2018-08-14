variable "ami_id" {
  description = "Amazon Linux 2"
  default = "ami-05868579"
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

variable "key_file_path" {
  description = "Private Key Path"
  default = "id_rsa_aws_jenkins"
}

provider "aws" {
  region      = "ap-southeast-1"
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
      user        = "ec2-user"
      private_key = "${file(var.key_file_path)}"
      agent       = false
      timeout     = "2m"
    }

    inline = [
      "sudo yum check-update",
      "sudo yum -y update",
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash",
      "chef-client --version",
    ]
  }
}

