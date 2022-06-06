terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    tls = {
      source = "hashicorp/tls"
      version = "3.4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    "Name" = var.main_vpc_name
  }
}

# Create a subnet
resource "aws_subnet" "web" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.web_subnet
  availability_zone = var.subnet_zone
  tags = {
    "Name" = "Web subnet"
  }
}

# Create a second subnet for ALB
resource "aws_subnet" "second_web" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.second_web_subnet
  availability_zone = var.second_subnet_zone
  tags = {
    "Name" = "Second web subnet"
  }
}

resource "aws_internet_gateway" "my_web_igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${var.main_vpc_name} IGW"
  }
}

resource "aws_default_route_table" "main_vpc_default_rt" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_web_igw.id
  }
  tags = {
    "Name" = "Default RT"
  }
}

resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    "Name" = "ALB Security Group"
  }
}

resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  tags = {
    "Name" = "Instance Security Group"
  }
}

resource "aws_key_pair" "ssh_key" {
  key_name = "quest_ssh_key"
  public_key = file(var.ssh_public_key)
}

# Data source for AWS Linux 2 AMI
data "aws_ami" "latest_amazon_linux2" {
  owners = [ "amazon" ]
  most_recent = true
  filter {
    name = "name"
    values = [ "amzn2-ami-kernel-*-x86_64-gp2" ]
  }

  filter {
    name = "architecture"
    values = [ "x86_64" ]
  }
}

# Quest EC2 Instance
resource "aws_instance" "quest_instance" {
  ami = data.aws_ami.latest_amazon_linux2.id
  instance_type = "t2.micro"
  subnet_id = aws_subnet.web.id
  vpc_security_group_ids = [ aws_security_group.instance_sg.id ]
  associate_public_ip_address = true
  key_name = aws_key_pair.ssh_key.key_name
  user_data = file("entry-script.sh")
  
  tags = {
    "Name" = "Quest Instance"
  }
}


# Application Load Balancer (ALB)
resource "aws_lb" "quest_alb" {
  name               = "quest-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [ aws_security_group.alb_sg.id ]
  subnets            = [ aws_subnet.web.id, aws_subnet.second_web.id ]

  tags = {
    Name = "Quest ALB"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "main_tg" {
  name     = "quest-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/loadbalanced"
  }
}

resource "aws_lb_target_group_attachment" "alb_tg_attachment" {
  target_group_arn = aws_lb_target_group.main_tg.arn
  target_id        = aws_instance.quest_instance.id
  port             = 3000
}

# ALB HTTP listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}

# ALB HTTPS listener with ACM cert
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.quest_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main_tg.arn
  }
}

# TLS Certificate creation
resource "tls_private_key" "tls_p_key" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "tls_ss_cert" {
  private_key_pem = tls_private_key.tls_p_key.private_key_pem

  subject {
    common_name  = "*.amazonaws.com"
    organization = "MyOrg"
  }

  validity_period_hours = 168

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# AWS ACM certificate creation
resource "aws_acm_certificate" "cert" {
  private_key      = tls_private_key.tls_p_key.private_key_pem
  certificate_body = tls_self_signed_cert.tls_ss_cert.cert_pem
}

# Adding ACM certificate to ALB HTTPS listener
resource "aws_lb_listener_certificate" "alb_listener_cert" {
  listener_arn    = aws_lb_listener.https_listener.arn
  certificate_arn = aws_acm_certificate.cert.arn
}
