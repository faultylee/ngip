//production environment
aws_region = "ap-southeast-1"
environment = "prod"
vpc_cidr = "10.10.0.0/16"
public_subnet_cidrs = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
availability_zones = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
pg_instance_class = "db.t2.micro"
pg_allocated_storage = "20"
//pg_username = ""
//pg_password = ""
pg_vpc_security_group_ids = ""
pg_subnet_id = ""
pg_version = "9.6.9"
pg_parameter_group = "9.6"
pg_snapshot_identifier = "general-2018-08-22-03-52"
pg_monitoring_interval = "5"
pg_backup_retention_period = "7"
pg_backup_window = "21:30-22:00"
elb_https_certificate = "arn:aws:acm:ap-southeast-1:288211158144:certificate/2ba60807-4a96-4ba0-bd30-95774c5db227"

