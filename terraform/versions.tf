# Pin Terraform and provider versions so every run (laptop or CI) uses the same
# code. "~> 6.69" allows 6.69.x and newer 6.x minors, but never a breaking 7.0.
terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags applied to every resource this provider creates.
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
