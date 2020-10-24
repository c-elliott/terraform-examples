# Local state
terraform {
  backend "local" {
    path = "./ec2-single.tfstate"
  }
}

# AWS provider relying on existing AWS config
provider "aws" {
  version = "~> 3.0"
  region  = "us-east-1"
  profile = "default"
}

# Get latest CentOS 7 AMI without SSM
data "aws_ami" "centos7" {
  most_recent = true
  filter {
    name   = "name"
    values = ["CentOS Linux 7 x86_64 HVM EBS ENA*"]
  }
  owners = ["679593333241"]
}

# Build instance
resource "aws_instance" "webserver" {
  ami           = data.aws_ami.centos7.id
  instance_type = "t3.micro"
  key_name      = "chris-mbp"
  tags = {
    Name  = "webserver"
    Owner = "terraform"
  }
}

# Output instance information
output "private_ip" {
  description = "Private IP"
  value       = aws_instance.webserver.private_ip
}
output "public_ip" {
  description = "Public IP"
  value       = aws_instance.webserver.public_ip
}
