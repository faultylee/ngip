provider "aws" {
  region      = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket = "ngip-private"
    key    = "stack/jenkins/jenkins.tfstate"
    region = "ap-southeast-1"
    encrypt = true
    acl = "private"
  }
}

// NOTE: This terraform file is only a placeholder, I'm importing the existing jenkins into the tfstate for ease of
// provisioning, to allow other tf files to read jenkins's tfstate. Will come back and complete this in the future

resource "aws_vpc" "jenkins-vpc" {
  cidr_block = "192.168.98.0/24"
}

resource "aws_internet_gateway" "jenkins-vpc" {

}

resource "aws_subnet" "jenkins-subnet-pub" {
  vpc_id = "${aws_vpc.jenkins-vpc.id}"
  cidr_block = "192.168.98.0/24"
}

resource "aws_route_table" "jenkins-subnet-pub" {
  vpc_id = "${aws_vpc.jenkins-vpc.id}"
}

resource "aws_eip" "jenkins" {}

resource "aws_security_group" "jenkins" {}

resource "aws_instance" "jenkins" {
  ami = "ami-8f5d2565"
  instance_type = "t2.medium"
}

output "jenkins-vpc-id" { value = "${aws_vpc.jenkins-vpc.id}" }
output "jenkins-subnet-pub-id" { value = "${aws_subnet.jenkins-subnet-pub.id}" }
output "jenkins-subnet-pub-route-id" { value = "${aws_route_table.jenkins-subnet-pub.id}" }
output "jenkins-subnet-pub-cidr" { value = "${aws_subnet.jenkins-subnet-pub.cidr_block}" }
