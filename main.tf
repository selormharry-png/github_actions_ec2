module "ec2" {
  #checkov:skip=CKV_TF_1:Registry module pinned by version; commit hashes only apply to git sources
  source  = "selormharry-png/ec2/aws"
  version = "1.0.3"


  environment        = var.environment
  instance_type      = var.instance_type
  key_name           = var.key_name
  project_name       = var.project_name
  public_subnet_cidr = var.public_subnet_cidr
  vpc_cidr           = var.vpc_cidr
}