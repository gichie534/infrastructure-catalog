provider "aws" {
  region = var.region
}

# Network for the cluster, built from the sibling vpc module. The cluster runs its
# nodes in the VPC's private subnets and reaches the internet via the NAT gateway.
module "vpc" {
  source = "../../../vpc"

  name       = "${var.name}-vpc"
  cidr_block = "10.0.0.0/16"

  azs                  = var.azs
  public_subnet_cidrs  = ["10.0.0.0/20", "10.0.16.0/20"]
  private_subnet_cidrs = ["10.0.128.0/20", "10.0.144.0/20"]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "../../"

  name               = var.name
  kubernetes_version = var.kubernetes_version

  # Nodes and control-plane ENIs run in the private subnets.
  subnet_ids = module.vpc.private_subnet_ids

  node_groups = {
    default = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
  }

  # Core add-ons plus the Pod Identity agent. Drop a key to leave it unmanaged.
  addons = {
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    eks-pod-identity-agent = {}
  }

  tags = {
    Environment = "example"
    ManagedBy   = "terraform"
  }
}
