terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "stack/middleware/ngip-stage.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}

data "terraform_remote_state" "shared" {
  backend = "s3"

  config {
    bucket = "ngip-private"
    key    = "stack/shared/ngip-stage.tfstate"
    region = "ap-southeast-1"
  }
}
