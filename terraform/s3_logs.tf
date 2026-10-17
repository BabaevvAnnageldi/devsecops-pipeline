# Log bucket: receives S3 server access logs from the data bucket.

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_18:This is the access-log target. Logging it to itself would loop; logging it elsewhere just moves the problem.
  #checkov:skip=CKV_AWS_144:Cross-region replication is out of scope for this single-region demo; logs are disposable after retention.
  #checkov:skip=CKV_AWS_145:S3 server access log delivery does not support SSE-KMS target buckets. SSE-S3 (AES256) is used instead.
  #checkov:skip=CKV2_AWS_62:No downstream consumer for event notifications on the log bucket.
  bucket_prefix = "${var.project_name}-${var.environment}-logs-"
}

# Owner owns every object; ACLs are disabled entirely.
resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket                  = aws_s3_bucket.logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3: the only option supported for access-log targets
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}

    expiration {
      days = var.log_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Only the S3 logging service, delivering logs for OUR data bucket in OUR
# account, may write here. Plain-HTTP access is denied.
data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "AllowS3ServerAccessLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.logs.arn}/access-logs/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.data.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.logs.arn, "${aws_s3_bucket.logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = data.aws_iam_policy_document.logs.json

  # Apply Block Public Access first so the bucket is never briefly exposed.
  depends_on = [aws_s3_bucket_public_access_block.logs]
}
