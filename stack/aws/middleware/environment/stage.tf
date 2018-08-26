terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "ngip-web-stage.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}

data "terraform_remote_state" "base" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "ngip-base-stage.tfstate"
    region = "ap-southeast-1"
  }
}
