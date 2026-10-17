variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Short project name, used in resource names and tags."
  type        = string
  default     = "devsecops-pipeline"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "project_name must be 3-20 chars: lowercase letters, digits, hyphens."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep old (noncurrent) object versions before deleting them."
  type        = number
  default     = 90
}

variable "log_retention_days" {
  description = "Days to keep S3 access logs."
  type        = number
  default     = 365
}

variable "kms_deletion_window_days" {
  description = "Waiting period before a deleted KMS key is destroyed (7-30)."
  type        = number
  default     = 30
}
