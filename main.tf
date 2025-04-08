# Terraform Config
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider Setup
provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "App_VPC"
  }
}

# Pubic Subnet
resource "aws_subnet" "app_public_subnet" {
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = "10.0.0.0/24"
  tags = {
    Name = "App_Public_Subnet"
  }
}

# IG
resource "aws_internet_gateway" "app_ig" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "App_IG"
  }
}

# RT
resource "aws_route_table" "app_public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_ig.id
  }
  tags = {
    Name = "App_RT"
  }
}

# Associate RT with Subnet
resource "aws_route_table_association" "app_public_assoc" {
  subnet_id = aws_subnet.app_public_subnet.id
  route_table_id = aws_route_table.app_public_rt.id
}

# EC2
resource "aws_instance" "app_ec2" {
  ami = "ami-084568db4383264d4"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.app_public_subnet.id
  tags = {
    Name = "Public_EC2"
  }
}