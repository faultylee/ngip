provider "aws" {
  region      = "${var.aws_region}"
}

data "terraform_remote_state" "jenkins" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "stack/jenkins/jenkins.tfstate"
    region = "ap-southeast-1"
  }
}

data "aws_s3_bucket_object" "key_file" {
  bucket = "ngip-private"
  key    = "ssh/id_rsa_ngip"
}

locals {
  environment = "${var.environment != "" ? var.environment: "local"}"
  name_prefix = "ngip-${local.environment}"
  // For prod specific setup
  is_prod = "${local.environment == "prod" ? 1 : 0}"
}

variable "aws_region" {}
variable "environment" {}
variable "vpc_cidr" {}
variable "public_subnet_cidrs" {
  type = "list"
}
variable "availability_zones" {
  type = "list"
}

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
    Name        = "${local.name_prefix}"
    Environment = "${local.name_prefix}"
  }
}

resource "aws_subnet" "ngip-subnet-pub" {
  vpc_id            = "${aws_vpc.ngip-vpc.id}"
  cidr_block        = "${element(var.public_subnet_cidrs, count.index)}"
  availability_zone = "${element(var.availability_zones, count.index)}"
  count             = "${length(var.public_subnet_cidrs)}"

  tags {
    Name        = "${local.name_prefix}-pub-${element(var.availability_zones, count.index)}"
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
  peer_vpc_id   = "${data.terraform_remote_state.jenkins.jenkins-vpc-id}"
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
  route_table_id         = "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-route-id}"
  gateway_id             = "${aws_vpc_peering_connection.peering_to_jenkins.id}"
  destination_cidr_block = "${element(aws_subnet.ngip-subnet-pub.*.cidr_block, count.index)}"
}

resource "aws_route" "peer_from_ngip_to_jenkins" {
  count = "${aws_route_table.ngip-subnet-pub.count}"
  route_table_id         = "${element(aws_route_table.ngip-subnet-pub.*.id, count.index)}"
  gateway_id             = "${aws_vpc_peering_connection.peering_to_jenkins.id}"
  destination_cidr_block = "${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"
}

########################
# RDS - Postgres
########################

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name               = "${local.name_prefix}rds-enhanced_monitoring-role"
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
    Name          = "${local.name_prefix}"
    Environment   = "${local.name_prefix}"
  }
}

resource "aws_security_group" "ngip-db" {
  name        = "${local.name_prefix}-db"
  description = "Security group for ngip-db"
  vpc_id      = "${aws_vpc.ngip-vpc.id}"

  tags {
    Name          = "${local.name_prefix}"
    Environment   = "${local.name_prefix}"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = "${var.public_subnet_cidrs}"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

}

resource "aws_db_instance" "ngip-db" {
  count = "1"

  identifier = "${local.environment}-ngip-db"

  engine            = "postgres"
  engine_version    = "${var.pg_version}"
  instance_class    = "${var.pg_instance_class}"
  storage_type      = "gp2"
  allocated_storage = "${var.pg_allocated_storage}"

  name                                = "ngip"
  username                            = "${var.pg_username}"
  password                            = "${var.pg_password}"

  //snapshot_identifier = "${var.pg_snapshot_identifier}"

  vpc_security_group_ids = ["${aws_security_group.ngip-db.id}"]
  db_subnet_group_name   = "${aws_db_subnet_group.ngip-db.name}"
  //parameter_group_name   = "${var.pg_parameter_group}"

  multi_az            = "${local.is_prod? true : false}"
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

########################
# Redis
########################

resource "aws_elasticache_subnet_group" "ngip-redis" {
  name = "${local.name_prefix}-ngip-redis-subnet"
  subnet_ids = ["${aws_subnet.ngip-subnet-pub.*.id}"]
}

resource "aws_security_group" "ngip-redis" {
  name = "${local.name_prefix}-redis"
  vpc_id      = "${aws_vpc.ngip-vpc.id}"

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = "${var.public_subnet_cidrs}"
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["${data.terraform_remote_state.jenkins.jenkins-subnet-pub-cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//resource "aws_elasticache_security_group" "ngip-redis" {
//  name = "${local.name_prefix}-redis"
//  security_group_names = ["${aws_security_group.ngip-redis.name}"]
//}

resource "aws_elasticache_replication_group" "ngip-redis" {
  automatic_failover_enabled    = "${local.is_prod}"
  // Terraform doesn't allow list creation within ternary operator, so hae to use join and split to get a single list
  // https://github.com/hashicorp/terraform/issues/12453#issuecomment-284273475
  availability_zones            = ["${split(",", local.is_prod ? join(",", var.availability_zones) : element(var.availability_zones, 0))}"]
  replication_group_id          = "${local.name_prefix}-rep-1"
  replication_group_description = "Redis Replication Group for ${local.name_prefix}"
  node_type                     = "cache.t2.micro"
  number_cache_clusters         = "${local.is_prod ? length(var.availability_zones) : 1 }"
  parameter_group_name          = "default.redis4.0"
  subnet_group_name             = "${aws_elasticache_subnet_group.ngip-redis.name}"
  security_group_ids            = ["${aws_security_group.ngip-redis.*.id}"]
  #transit_encryption_enabled    = true
  #auth_token                    = "${var.redis_password}"
}

########################
# IAM - ECR
########################

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

output "ngip-vpc-id" { value = "${aws_vpc.ngip-vpc.id}" }
output "ngip-db-address" { value = "${aws_db_instance.ngip-db.0.address}" }
output "ngip-redis-address" { value = "${aws_elasticache_replication_group.ngip-redis.primary_endpoint_address}" }
output "ngip-subnet-pub-id" { value = "${aws_subnet.ngip-subnet-pub.*.id}" }
output "ngip-availability-zones" { value = "${aws_subnet.ngip-subnet-pub.*.availability_zone}" }
output "ngip-ecr-readonly-id" { value = "${aws_iam_instance_profile.ngip-ecr-readonly-profile.id}" }
output "aws_region" { value = "${var.aws_region}"}
output "environment" { value = "${var.environment}"}