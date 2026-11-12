output "instance_id" {
  value       = module.ec2.instance_id
  description = "aws instance id to be output"
}

output "instance_public_ip" {
  value       = module.ec2.instance_public_ip
  description = "instance public ip to be output"
}


output "public_subnet_id" {
  value       = module.ec2.public_subnet_id
  description = "description"
}

output "security_group_id" {
  value       = module.ec2.security_group_id
  description = "description"
}


output "ssh_command" {
  value       = module.ec2.ssh_command
  description = "description"
}

output "vpc_id" {
  value       = module.ec2.vpc_id
  description = "description"
}
