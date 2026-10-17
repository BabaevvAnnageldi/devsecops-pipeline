output "data_bucket_name" {
  description = "Name of the encrypted data bucket."
  value       = aws_s3_bucket.data.id
}

output "log_bucket_name" {
  description = "Name of the access-log bucket."
  value       = aws_s3_bucket.logs.id
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key protecting the data bucket."
  value       = aws_kms_key.data.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key."
  value       = aws_kms_alias.data.name
}
