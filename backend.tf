# terraform {
#     backend "s3" {
#       bucket       = "securejambo14"
#       key          = "github_actions_ec2/terraform.tfstate"
#       region       = "eu-central-1"
#       encrypt      = true
#       use_lockfile = true
#     }
# }