provider "aws" {
    shared_credentials_files = ["C://Users//suryar//.aws//credentials"]
     profile  = "default"
     region = "us-west-2"  # Specify your desired region
}

# Adding the IAM Role which I have created by console
data "aws_iam_role" "existing_role" {
  name = "DemoRole"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
}


# Create a security group with inbound and outbound traffic for HTTP and SSH
resource "aws_security_group" "alg_sg" {
  name        = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "defaultVpcSg"
  }
}

# Create an ALB
resource "aws_lb" "app_lb" {
  name               = "demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alg_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    name = "demo-lb"
  }
}

# Create an ALB target group
resource "aws_lb_target_group" "app_tg" {
  name     = "demo-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path = "/"
    interval = 30
    timeout = 5
    healthy_threshold = 2
    unhealthy_threshold = 2
    matcher = "200"
  }
}

# Create a listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_security_group" "ec2_sg" {
  name = "ec2-sg"
  description = "Security group for EC2 instaces"
  vpc_id = data.aws_vpc.default.id

  ingress {
    protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    name = "EC2SG"
  }
}
# Create an Launch template
resource "aws_launch_template" "web-server" {
  name_prefix          = "example-lt"
  instance_type        = "t2.micro"
  image_id = "ami-07d9cf938edb0739b"
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Use this for your user data (script from top to bottom)
              # install httpd (Linux 2 version)
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
              EOF 
              )
  network_interfaces {
    security_groups =  [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = "terraformLtTemplate"
  }
}

resource "aws_autoscaling_group" "demo-asg" {
  desired_capacity = 3
  min_size = 1
  max_size = 4
  vpc_zone_identifier = data.aws_subnets.default.ids
  launch_template {
    id = aws_launch_template.web-server.id
    version = "$Latest"
  }
  target_group_arns = [aws_lb_target_group.app_tg.arn]
  health_check_type = "EC2"
  tag {
    key = "Name"
    value = "demo-instance"
    propagate_at_launch = true
  }
  
}


# Output the DNS name of the ALB
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}


output "default_vpc_id" {
  value = data.aws_vpc.default.id
}

output "default_subnets" {
  value = data.aws_subnets.default.ids
}