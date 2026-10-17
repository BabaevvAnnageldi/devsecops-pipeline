# !!! DELIBERATELY INSECURE. DO NOT DEPLOY !!!
#
# This file exists to prove the pipeline's IaC gate works. It keeps the
# .example extension so Terraform and Checkov ignore it on main.
#
# Demo: copy it into terraform/ as insecure.tf on a branch, open a PR, and watch
# the iac-scan job go red.

# 1. Public S3 bucket: Block Public Access turned OFF, public-read ACL, and a
#    bucket policy that lets anyone on the internet read every object.
resource "aws_s3_bucket" "insecure_public" {
  bucket_prefix = "insecure-demo-public-"
}

resource "aws_s3_bucket_public_access_block" "insecure_public" {
  bucket                  = aws_s3_bucket.insecure_public.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_ownership_controls" "insecure_public" {
  bucket = aws_s3_bucket.insecure_public.id
  rule {
    object_ownership = "BucketOwnerPreferred" # re-enables ACLs
  }
}

resource "aws_s3_bucket_acl" "insecure_public" {
  bucket     = aws_s3_bucket.insecure_public.id
  acl        = "public-read"
  depends_on = [aws_s3_bucket_ownership_controls.insecure_public]
}

resource "aws_s3_bucket_policy" "insecure_public" {
  bucket = aws_s3_bucket.insecure_public.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.insecure_public.arn}/*"
    }]
  })
}

# 2. No encryption, no versioning, no logging, no lifecycle: none of the
#    hardening resources from s3_data.tf exist for this bucket.

# 3. SSH open to the entire internet.
resource "aws_security_group" "insecure_ssh" {
  name        = "insecure-demo-ssh"
  description = "Deliberately insecure: SSH from anywhere"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
