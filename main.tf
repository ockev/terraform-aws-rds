# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  # optional but recommended:
  # required_version = ">= 1.3.0"
}

provider "aws" {
  region = "us-east-1"
}

provider "random" {}

data "aws_availability_zones" "available" {}

resource "random_pet" "random" {}

# ------------------------------------------------------------------------------
# 1) VPC
# ------------------------------------------------------------------------------
resource "aws_vpc" "education" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${random_pet.random.id}-education-vpc"
  }
}

# ------------------------------------------------------------------------------
# 2) Public subnets
#    We'll place them in the first three AZs from data.aws_availability_zones.
# ------------------------------------------------------------------------------
resource "aws_subnet" "education_public_az1" {
  vpc_id                  = aws_vpc.education.id
  cidr_block             = "10.0.4.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${random_pet.random.id}-az1"
  }
}

resource "aws_subnet" "education_public_az2" {
  vpc_id                  = aws_vpc.education.id
  cidr_block             = "10.0.5.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "${random_pet.random.id}-az2"
  }
}

resource "aws_subnet" "education_public_az3" {
  vpc_id                  = aws_vpc.education.id
  cidr_block             = "10.0.6.0/24"
  availability_zone       = data.aws_availability_zones.available.names[2]
  map_public_ip_on_launch = true

  tags = {
    Name = "${random_pet.random.id}-az3"
  }
}

# ------------------------------------------------------------------------------
# 3) Internet Gateway
# ------------------------------------------------------------------------------
resource "aws_internet_gateway" "education" {
  vpc_id = aws_vpc.education.id

  tags = {
    Name = "${random_pet.random.id}-education-igw"
  }
}

# ------------------------------------------------------------------------------
# 4) Public Route Table + routes
# ------------------------------------------------------------------------------
resource "aws_route_table" "education_public" {
  vpc_id = aws_vpc.education.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.education.id
  }

  tags = {
    Name = "${random_pet.random.id}-education-public-rtb"
  }
}

# ------------------------------------------------------------------------------
# 5) Route table associations for each public subnet
# ------------------------------------------------------------------------------
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.education_public_az1.id
  route_table_id = aws_route_table.education_public.id
}

resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.education_public_az2.id
  route_table_id = aws_route_table.education_public.id
}

resource "aws_route_table_association" "public_az3" {
  subnet_id      = aws_subnet.education_public_az3.id
  route_table_id = aws_route_table.education_public.id
}

# ------------------------------------------------------------------------------
# 6) RDS Subnet Group (use the 3 public subnets)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "education" {
  name       = "${random_pet.random.id}-education"
  subnet_ids = [
    aws_subnet.education_public_az1.id,
    aws_subnet.education_public_az2.id,
    aws_subnet.education_public_az3.id,
  ]

  tags = {
    Name = "${random_pet.random.id}-education"
  }
}

# ------------------------------------------------------------------------------
# 7) Security Group for RDS
# ------------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name   = "${random_pet.random.id}-education_rds"
  vpc_id = aws_vpc.education.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["192.80.0.0/16"]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${random_pet.random.id}-education_rds"
  }
}

# ------------------------------------------------------------------------------
# 8) Optional Parameter Group
# ------------------------------------------------------------------------------
resource "aws_db_parameter_group" "education" {
  name   = "${random_pet.random.id}-education"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

# ------------------------------------------------------------------------------
# 9) RDS Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "education" {
  identifier             = "${var.db_name}-${random_pet.random.id}"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "15.7"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true

  tags = {
    Name = "${var.db_name}-${random_pet.random.id}"
  }
}
