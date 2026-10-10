terraform {
  required_version = "~> 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend blocks cannot use variables, so these values are hardcoded per
  # environment. The bucket is created by ../../bootstrap.py.
  backend "s3" {
    bucket       = "ecs-prod-tfstate"
    key          = "ecs/prod/terraform.tfstate"
    region       = "eu-central-1"
    profile      = "ecs-prod"
    use_lockfile = true # native S3 locking, no DynamoDB table needed
    encrypt      = true
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region

  default_tags {
    tags = {
      Project     = "ecs-demo"
      Environment = var.environment
      Terraform   = "true"
    }
  }
}

#------------------------------------------------------------------------------
# Network (off-the-shelf community module)
#------------------------------------------------------------------------------

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.environment
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  # NAT matters beyond HA: Fargate tasks in private subnets pull the public
  # image and reach Secrets Manager / CloudWatch through it. Prod runs one
  # NAT per AZ (single_nat_gateway = false); dev would use one shared NAT.
  enable_nat_gateway = true
  single_nat_gateway = var.single_nat_gateway

  enable_dns_support   = true
  enable_dns_hostnames = true
}

#------------------------------------------------------------------------------
# Cluster (per environment; multiple services would share it)
#------------------------------------------------------------------------------

resource "aws_ecs_cluster" "this" {
  name =  "ecs_${var.environment}"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}

#------------------------------------------------------------------------------
# Service
#------------------------------------------------------------------------------

module "app" {
  source = "../../modules/ecs-service"

  name        = var.service_name
  environment = var.environment

  cluster_arn        = aws_ecs_cluster.this.arn
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  container_image = var.container_image
  container_port  = var.container_port
  task_cpu        = var.task_cpu
  task_memory     = var.task_memory

  desired_count                = var.desired_count
  min_capacity                 = var.min_capacity
  max_capacity                 = var.max_capacity
  cpu_target_utilization       = var.cpu_target_utilization
  enable_request_count_scaling = var.enable_request_count_scaling
  requests_per_target          = var.requests_per_target

  redis_endpoint          = var.redis_endpoint
  redis_security_group_id = var.redis_security_group_id

  app_secret_value = var.app_secret_value

  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  enable_circuit_breaker_rollback    = var.enable_circuit_breaker_rollback
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  log_retention_in_days              = var.log_retention_in_days
}
