# Note:
# Terraform currently does not have a mechanism for calling
# the instance refresh autoscaling feature, to replace instances
# following update of a launch template. 
# https://github.com/terraform-providers/terraform-provider-aws/issues/13785
# https://docs.aws.amazon.com/autoscaling/ec2/userguide/asg-instance-refresh.html

# Local state
terraform {
  backend "local" {
    path = "./ec2-autoscale.tfstate"
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

# Get ID of default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnet IDs from default VPC
data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

# Create userdata for launch template
data "template_file" "foo_userdata" {
  template = <<EOF
#!/bin/bash
yum -y install httpd
systemctl start httpd
systemctl enable httpd
EOF
}

# Create launch template
resource "aws_launch_template" "foo" {
  name          = "foo"
  image_id      = data.aws_ami.centos7.id
  instance_type = "t3.nano"
  key_name      = "chris-mbp"
  user_data     = base64encode(data.template_file.foo_userdata.rendered)
  tags = {
    Name  = "foo"
    Owner = "terraform"
  }
}

# Build ASG
resource "aws_autoscaling_group" "foogroup" {
  name                      = "${aws_launch_template.foo.name}-asg"
  vpc_zone_identifier       = data.aws_subnet_ids.all.ids
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.foo.id
    version = "$Latest"
  }
  tags = [
    {
      key                 = "Name"
      value               = "foogroup_autoscale"
      propagate_at_launch = true
    },
    {
      key                 = "Owner"
      value               = "terraform"
      propagate_at_launch = true
    }
  ]
}
