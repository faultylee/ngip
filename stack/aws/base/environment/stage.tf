terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "stack/shared/ngip-stage.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}
