# Intentionally insecure Terraform config — for testing security scanner and cost optimizer

provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAIOSFODNN7EXAMPLE"         # SEC001: Hardcoded access key
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"  # SEC002: Hardcoded secret
}

# ── VPC (no flow logs) ────────────────────────────────────────
resource "aws_vpc" "main" {                     # SEC051: No flow logs
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main-vpc"
  }
}

# ── Security Group: SSH open to world ─────────────────────────
resource "aws_security_group" "bad_sg" {
  name        = "wide-open-sg"
  description = "Intentionally insecure SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22                            # SEC011: SSH open to world
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]                 # SEC010: Open to world
  }

  ingress {
    description = "RDP from anywhere"
    from_port   = 3389                          # SEC012: RDP open to world
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "All ports open"
    from_port   = 0                             # SEC013: All ports open
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── S3 Bucket: Public ────────────────────────────────────────
resource "aws_s3_bucket" "public_bucket" {       # SEC021, SEC022: No encryption/versioning
  bucket = "my-public-data-bucket"
  acl    = "public-read"                         # SEC020: Public ACL
}

# ── RDS: Publicly accessible, no encryption ──────────────────
resource "aws_db_instance" "bad_rds" {
  allocated_storage    = 100
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.m4.xlarge"           # COST002: Previous-gen
  db_name             = "mydb"
  username            = "admin"
  password            = "SuperSecretPassword123!" # SEC002: Hardcoded password
  publicly_accessible = true                      # SEC032: Public RDS
  storage_encrypted   = false                     # SEC031: No encryption
  multi_az            = true                      # COST008: Multi-AZ (check if prod)
  skip_final_snapshot = true
}

# ── EC2: Oversized, previous gen, no autoscaling ─────────────
resource "aws_instance" "big_server" {            # COST006, COST009: No Spot/scaling
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "m4.4xlarge"                    # COST001: Oversized, COST002: Previous-gen
  key_name      = "my-keypair"

  root_block_device {
    volume_type = "gp2"                           # COST003: gp2 instead of gp3
    volume_size = 100
    encrypted   = false                           # SEC030: Unencrypted EBS
  }

  tags = {
    Name = "big-server"
  }
}

# ── EBS Volume ───────────────────────────────────────────────
resource "aws_ebs_volume" "data" {
  availability_zone = "us-east-1a"
  size             = 500
  type             = "gp2"                        # COST003: gp2
  encrypted        = false                        # SEC030: Unencrypted
}

# ── NAT Gateway ──────────────────────────────────────────────
resource "aws_nat_gateway" "nat_1" {              # COST004: NAT Gateway cost
  allocation_id = aws_eip.nat_1.id
  subnet_id     = "subnet-12345"
}

resource "aws_nat_gateway" "nat_2" {              # COST004: Another NAT Gateway
  allocation_id = aws_eip.nat_2.id
  subnet_id     = "subnet-67890"
}

resource "aws_eip" "nat_1" {}                     # COST007: EIP
resource "aws_eip" "nat_2" {}                     # COST007: EIP

# ── IAM Policy: Wildcard ─────────────────────────────────────
resource "aws_iam_policy" "overly_permissive" {
  name   = "admin-like-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"                              # SEC040: Wildcard actions
      Resource = "*"                              # SEC041: Wildcard resources
    }]
  })
}

# ── CloudTrail: Logging disabled ─────────────────────────────
resource "aws_cloudtrail" "audit" {
  name                  = "audit-trail"
  s3_bucket_name        = aws_s3_bucket.public_bucket.id
  enable_logging        = false                   # SEC050: Logging disabled
}

# ── CloudWatch Log Group ─────────────────────────────────────
resource "aws_cloudwatch_log_group" "app_logs" {   # COST010: No retention
  name = "/app/my-service"
}
