provider "aws" {
  region      = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "${var.tfstate_name}"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}
variable "tfstate_name" {}
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
variable "short_availability_zones" {
  type = "list"
}

variable "pg_end_point" { default = ""}
variable "pg_instance_class" {}
variable "pg_version" {}
variable "pg_parameter_group" {}
variable "pg_allocated_storage" {}
variable "pg_username" {}
variable "pg_password" {}
variable "pg_vpc_security_group_ids" {}
variable "pg_subnet_id" {}
variable "pg_snapshot_identifier" {}
variable "pg_backup_window" {}
variable "pg_backup_retention_period" {}
variable "pg_monitoring_interval" {}

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
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
  // If end point is provided, skip RDS creation
  create_rds = "${var.pg_end_point != "" ? false : true}"
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
  cidr_block        = "${element(var.public_subnet_cidrs, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  count             = "${length(var.public_subnet_cidrs)}"

  tags {
    Name        = "${local.name_prefix}-pub-${element(var.short_availability_zones, count.index)}"
    Environment = "${local.name_prefix}"
  }
}

resource "aws_route_table" "ngip-subnet-pub" {
  vpc_id          = "${aws_vpc.ngip-vpc.id}"
  count           = "${length(var.public_subnet_cidrs)}"

  tags {
    Name          = "${local.name_prefix}-pub-${element(var.availability_zones, count.index)}"
    Environment   = "${local.name_prefix}"
  }
}

resource "aws_route_table_association" "subnet" {
  subnet_id       = "${element(aws_subnet.ngip-subnet-pub.*.id, count.index)}"
  route_table_id  = "${element(aws_route_table.ngip-subnet-pub.*.id, count.index)}"
  count           = "${length(var.public_subnet_cidrs)}"
}

resource "aws_route" "public_igw_route" {
  count                  = "${aws_route_table.ngip-subnet-pub.count}"
  route_table_id         = "${element(aws_route_table.ngip-subnet-pub.*.id, count.index)}"
  gateway_id             = "${aws_internet_gateway.ngip-vpc.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_vpc_peering_connection" "peering_to_jenkins" {
  peer_vpc_id   = "${var.vpc_jenkins}"
  vpc_id        = "${aws_vpc.ngip-vpc.id}"
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = false
  }

  requester {
    allow_remote_vpc_dns_resolution = false
  }
}

resource "aws_route" "peer_from_jenkins_to_ngip" {
  count = "${aws_route_table.ngip-subnet-pub.count}"
  route_table_id         = "${var.subnet_pub_jenkins_route}"
  gateway_id             = "${aws_vpc_peering_connection.peering_to_jenkins.id}"
  destination_cidr_block = "${element(aws_subnet.ngip-subnet-pub.*.cidr_block, count.index)}"
}

resource "aws_route" "peer_from_ngip_to_jenkins" {
  count = "${aws_route_table.ngip-subnet-pub.count}"
  route_table_id         = "${element(aws_route_table.ngip-subnet-pub.*.id, count.index)}"
  gateway_id             = "${aws_vpc_peering_connection.peering_to_jenkins.id}"
  destination_cidr_block = "${var.subnet_pub_jenkins_cidr}"
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
//  tags = "${merge(var.tags, map("Name", format("%s", var.name)))}"
//}

########################
# EC2 Web
########################

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
  count           = 1
  ami             = "${var.ami_id_al2}"
  instance_type   = "${var.instance_type}"
  tags {
    Name = "${local.name_prefix}-web-${element(var.short_availability_zones, count.index)}"
  }

  key_name        = "${var.key_file}"
  associate_public_ip_address = true
  subnet_id       = "${element(aws_subnet.ngip-subnet-pub.*.id, var.az_index)}"

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
      "sudo chef-solo -c solo.rb -o test::default"
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

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "rds-enhanced_monitoring-role"
  assume_role_policy = "${data.aws_iam_policy_document.rds_enhanced_monitoring.json}"
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = "${aws_iam_role.rds_enhanced_monitoring.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_db_subnet_group" "ngip-db" {
  count = 1

  name_prefix = "${local.name_prefix}"
  subnet_ids  = ["${aws_subnet.ngip-subnet-pub.*.id}"]

  tags {
    Environment   = "${local.name_prefix}"
  }
}

resource "aws_security_group" "ngip-db" {
  name        = "${local.name_prefix}-db"
  description = "Security group for ngip-db"
  vpc_id      = "${aws_vpc.ngip-vpc.id}"

  tags {
    Environment   = "${local.name_prefix}"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = "${var.public_subnet_cidrs}"
  }

}

resource "aws_db_instance" "ngip-db" {
  count = "${local.create_rds? 1 : 0}"

  identifier = "${local.environment}-ngip-db"

  engine            = "postgres"
  engine_version    = "${var.pg_version}"
  instance_class    = "${var.pg_instance_class}"
  allocated_storage = "${var.pg_allocated_storage}"

  name                                = "ngip"
  username                            = "${var.pg_username}"
  password                            = "${var.pg_password}"

  //snapshot_identifier = "${var.pg_snapshot_identifier}"

  vpc_security_group_ids = ["${aws_security_group.ngip-db.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.ngip-db.name}"
  //parameter_group_name   = "${var.pg_parameter_group}"

  availability_zone   = "${element(var.availability_zones, var.az_index)}"
  publicly_accessible = false
  monitoring_interval = "${var.pg_monitoring_interval}"
  monitoring_role_arn = "${aws_iam_role.rds_enhanced_monitoring.arn}"


  backup_retention_period = "${var.pg_backup_retention_period}"
  backup_window           = "${var.pg_backup_window}"

  skip_final_snapshot = "${local.is_prod ? false : true}"
  final_snapshot_identifier = "${local.environment}-ngip-db-final-snapshot"

  // Not supported for Postgres
  //enabled_cloudwatch_logs_exports = ["audit", "error", "general", "slowquery"]

  tags = {
    Environment = "${local.name_prefix}"
  }

}

output "ngip_web_public_ip" {
  value = "${aws_instance.ngip-web.*.public_ip}"
}

output "ngip_db_address" {
  value = "${aws_db_instance.ngip-db.*.address}"
}
