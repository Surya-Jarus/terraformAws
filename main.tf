
provider "aws" {
    shared_credentials_files = ["credentials location"]
     profile  = "default"
     region = "ap-south-1"  # Specify your desired region
}
#to create a AWS VPC
resource "aws_vpc" main{
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main-vpc"
    }
}
#create a subnet associate with VPC
resource "aws_subnet" "main" {
    vpc_id     = aws_vpc.main.id
    cidr_block = "10.0.1.0/24"

    tags = {
      Name = "main-subnet"
  }
}
#adding the IAM Role which i have created by console
data "aws_iam_role" "existing_role" {
  name = "DemoRole"
}

#create a AWS IAM instance profile basned on the role
resource "aws_iam_instance_profile" "example_instance_profile" {
  name = "example_instance_profile"
  role = data.aws_iam_role.existing_role.name
}

#create a security group with inbound and outbound traffic for http and ssh
resource "aws_security_group" "main" {
    name = "allow_http"
    description = "Allow http traffic"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol =  -1
        cidr_blocks = ["0.0.0.0/0"]
    }
}

#create an instace
resource "aws_instance" web-server{

    ami = "ami-0fd05997b4dff7aac"
    instance_type = "t2.micro"
    iam_instance_profile =  aws_iam_instance_profile.example_instance_profile.name
    key_name = "my-first-instance"
     subnet_id = aws_subnet.main.id
    vpc_security_group_ids = [aws_security_group.main.id]

    tags = {
        name = "terraformFirstInstance"
    }

}