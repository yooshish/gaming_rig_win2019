# Define Provider to be used.
terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = ">= 3.5"
      }
    }
}

provider "aws" {
  region = "us-west-1"

  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Create a VPC
resource "aws_vpc" "gaming_rig_vpc" {
  cidr_block = "10.0.0.0/24"

  tags = "${merge(var.tags,
            tomap({"Name"="public_gaming_rig_vpc"}))
          }"

}

resource "aws_subnet" "public_gaming_rig_subnet" {
  vpc_id = aws_vpc.gaming_rig_vpc.id
  cidr_block = "10.0.0.0/28"

  tags = "${merge(var.tags,
            tomap({"Name"="public_gaming_rig_subnet"}))
          }"
}

# Add in networking - route table, internet gateway
#resource ""

# Create new EC2 and associate with the public_gaming_rig_vpc and public_gaming_rig_subnet.