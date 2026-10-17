# Customer-managed KMS key for the data bucket.
# Unlike AWS-managed keys, a CMK lets us control the key policy, audit key use
# in CloudTrail, and disable/rotate the key ourselves.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
}

resource "aws_kms_key" "data" {
  description             = "${var.project_name}-${var.environment} S3 data bucket encryption key"
  enable_key_rotation     = true # rotate key material automatically every year
  deletion_window_in_days = var.kms_deletion_window_days

  # Explicit key policy. Without one, AWS applies a default policy; writing it
  # out makes the access model reviewable in code.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Standard statement: lets IAM policies in this account grant access to
        # the key. Without it the key can become unmanageable.
        Sid       = "EnableIAMPolicies"
        Effect    = "Allow"
        Principal = { AWS = local.account_root_arn }
        Action    = "kms:*"
        Resource  = "*" # in a key policy, "*" means "this key"
      },
      {
        # Allow S3 to use the key only on behalf of this account.
        Sid       = "AllowS3UseFromThisAccount"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = ["kms:GenerateDataKey", "kms:Decrypt"]
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.project_name}-${var.environment}-s3-data"
  target_key_id = aws_kms_key.data.key_id
}
