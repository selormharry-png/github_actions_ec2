variable "environment" {
  default     = "dev"
  type        = string
  description = "the environment to deploy to"
}

variable "instance_type" {
  default     = "t3.micro"
  type        = string
  description = "the type of instance to be provisioned"
}


variable "key_name" {
  default     = "safe_key"
  type        = string
  description = "ssh key"
}

variable "project_name" {
  default     = "duplicate12"
  type        = string
  description = "aws name for the ec2 instance"
}


variable "vpc_cidr" {
  default     = "10.0.0.0/16"
  type        = string
  description = "aws vpc cidr block"
}

variable "public_subnet_cidr" {
  default     = "10.0.1.0/24"
  type        = string
  description = "description"
}
