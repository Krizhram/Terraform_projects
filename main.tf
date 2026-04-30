terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.39.0"
    }
  }
}


provider "aws" {
  region = "ap-south-1"
}

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-123"
    key            = "terraform-project/terraform.tfstate"
    region         = "us-east-1"
  }
}



locals {
  project_name       = "my_project"
  availability_zones = ["ap-south-1a", "ap-south-1b"]
  subnet_types       = ["public", "private"]
}

resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${local.project_name}-vpc"
  }

}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = element(local.availability_zones, count.index)
  map_public_ip_on_launch = element([true, false], count.index % 2)
  count                   = 4
  tags = {
    Name = "${local.project_name}-subnet-${count.index}"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "${local.project_name}-igw"
  }

}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${local.project_name}-public-rt"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "${local.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public_rt_assoc" {
  count          = 2
  subnet_id      = aws_subnet.main[count.index].id
  route_table_id = element([aws_route_table.public_rt.id, aws_route_table.private_rt.id], count.index % 2)

}

resource "aws_instance" "main" {
  for_each      = var.ec2_map
  ami           = each.value.ami
  instance_type = each.value.instance_type
  subnet_id     = element(aws_subnet.main[*].id, index(keys(var.ec2_map), each.key) % length(aws_subnet.main))

  tags = {
    Name = "${local.project_name}-instance-${each.key}"
  }
}

output "aws_details" {
  value = {
    subnet_ids   = aws_subnet.main[*].id
    instance_ips = [for instance in aws_instance.main : instance.public_ip]
  }
}
