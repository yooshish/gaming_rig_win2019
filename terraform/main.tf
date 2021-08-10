##
## Define Provider to be used.
##
terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = ">= 3.5"
      }
    }
}

provider "aws" {
  region     = "us-west-1"

  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

##
## 1. Setup networking: create a VPC, IGW, Subnets, Route Table, and Route Table Association to Subnet
##
resource "aws_vpc" "gaming_rig_vpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  
  tags        = "${merge(var.tags,
                  tomap({"Name"="gaming-rig-vpc"}))
                }"
}

resource "aws_internet_gateway" "gaming_rig_igw" {
  vpc_id = aws_vpc.gaming_rig_vpc.id

  tags   = "${merge(var.tags,
            tomap({"Name"="gaming-rig-ig"}))
          }"
}

resource "aws_default_route_table" "gaming_rig_route_table" {
  default_route_table_id = aws_vpc.gaming_rig_vpc.default_route_table_id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.gaming_rig_igw.id}"
  }

  tags = "${merge(var.tags,
            tomap({"Name"="gaming-rig-route-table"}))
          }"
}

resource "aws_subnet" "public_gaming_rig_subnet" {
  vpc_id     = aws_vpc.gaming_rig_vpc.id
  cidr_block = "10.0.0.0/28"

  tags       = "${merge(var.tags,
                  tomap({"Name"="public-subnet"}))
                }"
}

## Consider a NAT network for private subnet...
# 1. Create an Elastic IP
# 2. Create an aws_nat_gateway resource attached to the public subnet id
# 3. Create an aws_route_table resource 
# 4. Create another aws_route_table_association resource tying the NAT route table with the private subnet

resource "aws_route_table_association" "route_table_assoc" {
  subnet_id      = aws_subnet.public_gaming_rig_subnet.id
  route_table_id = aws_default_route_table.gaming_rig_route_table.id
}

##
## 2. Setup compute: create a new EC2 (the gaming rig) on a Windows Server 2019 and associate
##    with the public_gaming_rig_vpc, public_gaming_rig_subnet, custom security group, and key pair.
##
data "aws_ami" "win_server_2019_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  owners = ["801119661308"]
}

resource "aws_security_group" "gaming_rig_rdp_sg" {
  name   = "gaming-rig-sg"
  vpc_id = aws_vpc.gaming_rig_vpc.id

  ingress {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = ["${var.my_ip}/32"]
  }

  egress {

      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

}

resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename          = "yoosh-key.pem"
  sensitive_content = tls_private_key.tls_key.private_key_pem
  file_permission   = "0400"

}
resource "aws_key_pair" "key_pair" {
  key_name   = "yoosh-key"       # Create a "my-key" to AWS
  public_key = tls_private_key.tls_key.public_key_openssh

  # provisioner "local-exec" { # Create a "my-key.pem" to your computer
  #   command = "echo '${tls_private_key.private_key.private_key_pem}' > ./my-key.pem"
  # }
}

resource "aws_instance" "gaming_rig" {
  ami                         = data.aws_ami.win_server_2019_ami.id
  instance_type               = var.rig_instance_size
  key_name                    = aws_key_pair.key_pair.key_name
  associate_public_ip_address = true

  root_block_device {
    delete_on_termination = true # This may need to change if we snapshot
    encrypted             = true # Explore how this affects performance
    volume_size           = var.rig_disk_size
  }

  subnet_id = aws_subnet.public_gaming_rig_subnet.id
  vpc_security_group_ids = [aws_security_group.gaming_rig_rdp_sg.id]
  tags        = "${merge(var.tags,
                  tomap({"Name"="gaming-rig"}))
                }"

  volume_tags = "${merge(var.tags,
                  tomap({"Name"="public-subnet"}))
                }"
}

resource "aws_eip" "eip" {
  vpc        = true
  instance   = aws_instance.gaming_rig.id
  depends_on = [aws_internet_gateway.gaming_rig_igw,]
}