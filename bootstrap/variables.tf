variable "common_tags" {
  type        = map(string)
  description = "name for the provisioned resources"

  default = {
    Name      = "nice_wish"
    Project   = "dev"
    ManagedBy = "terraform"
  }
}

variable "bucket_name" {
  default     = "securejambo14"
  type        = string
  description = "description"
}

variable "aws_profile_name" {
  default     = "Kloud-Messiah"
  type        = string
  description = "description"
}

variable "aws_region" {
  default     = "eu-central-1"
  type        = string
  description = "description"
}
