terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "aws-profile-name"
}

resource "aws_vpc" "demo-vpc" {
  cidr_block = "10.0.0.0/26"
  tags = {Name = "demo-vpc"}
}

resource "aws_subnet" "private-subnet" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.0.0/27"
  availability_zone = "eu-central-1a"
  tags = {Name = "private-subnet"}
}

resource "aws_subnet" "public-subnet" {
  vpc_id     = aws_vpc.demo-vpc.id
  cidr_block = "10.0.0.32/27"
  availability_zone = "eu-central-1b"
  tags = {Name = "public-subnet"}
}

resource "aws_internet_gateway" "demo-igw" {
  vpc_id = aws_vpc.demo-vpc.id
  tags = {Name = "demo-igw"}
}

resource "aws_route_table_association" "public-subnet-to-public-rt" {
  subnet_id      = aws_subnet.public-subnet.id
  route_table_id = aws_default_route_table.public-rt.id
}

resource "aws_eip" "demo-ngw-eip" {
  vpc = true
}

resource "aws_nat_gateway" "demo-ngw" {
  allocation_id = aws_eip.demo-ngw-eip.id
  subnet_id     = aws_subnet.public-subnet.id
  tags = {Name = "demo-ngw"}
  depends_on = [aws_internet_gateway.demo-igw]
}

resource "aws_default_route_table" "public-rt" {
  default_route_table_id = aws_vpc.demo-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo-igw.id
  }
  tags = {Name = "public-rt"}
}

resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.demo-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.demo-ngw.id
  }
  tags = {Name = "private-rt"}
}

resource "aws_route_table_association" "private-subnet-to-private-rt" {
  subnet_id      = aws_subnet.private-subnet.id
  route_table_id = aws_route_table.private-rt.id
}

resource "aws_security_group" "allow-ssh-http-sg" {
  name = "allow-ssh-http-sg"
  vpc_id     = aws_vpc.demo-vpc.id
  depends_on = [aws_security_group.demo-alb-sg]
  ingress {
      from_port = 22
      to_port = 22
      protocol = "tcp"
      cidr_blocks = ["your_public_ip_from_whatismyip/32"]
    }
  ingress {
      from_port = 0
      to_port = 0
      protocol = "-1"
      security_groups = [aws_security_group.demo-alb-sg.id]
    }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "public-app-1" {
  ami           = "ami-00aeecd0dba04f3d8"
  instance_type = "t2.micro"
  key_name      = "demo"
  associate_public_ip_address = "true"
  vpc_security_group_ids = [ aws_security_group.allow-ssh-http-sg.id ]
  subnet_id = aws_subnet.public-subnet.id
  tags = {Name = "public-app-1"}
}

resource "aws_instance" "public-app-2" {
  ami           = "ami-00aeecd0dba04f3d8"
  instance_type = "t2.micro"
  key_name      = "demo"
  associate_public_ip_address = "true"
  vpc_security_group_ids = [ aws_security_group.allow-ssh-http-sg.id ]
  subnet_id = aws_subnet.public-subnet.id
  tags = {Name = "public-app-2"}
}

resource "aws_security_group" "demo-alb-sg" {
  name        = "demo-alb-sg"
  vpc_id     = aws_vpc.demo-vpc.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["your_public_ip_from_whatismyip/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["your_public_ip_from_whatismyip/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {Name = "demo-alb-sg"}
}

resource "aws_alb" "demo-alb" {
  name            = "demo-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.demo-alb-sg.id]
  subnets         = [aws_subnet.public-subnet.id, aws_subnet.private-subnet.id]
  tags = {Name = "demo-alb"}
}

resource "aws_alb_target_group" "demo-tg" {
  name     = "demo-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.demo-vpc.id
  health_check {
    path = "/"
    port = 80
  }
}

resource "aws_alb_listener" "demo-alb-listener-http" {
  load_balancer_arn = aws_alb.demo-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.demo-tg.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group_attachment" "docker-1" {
  target_group_arn = aws_alb_target_group.demo-tg.arn
  target_id        = aws_instance.public-app-1.id
  port             = 80
}

resource "aws_alb_target_group_attachment" "docker-2" {
  target_group_arn = aws_alb_target_group.demo-tg.arn
  target_id        = aws_instance.public-app-2.id
  port             = 80
}
