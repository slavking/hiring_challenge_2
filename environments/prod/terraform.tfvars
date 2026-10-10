aws_profile  = "ecs-prod"
region       = "eu-central-1"
environment  = "prod"
service_name = "app"

#------------------------------------------------------------------------------
# Network — prod HA: 3 AZs, one NAT gateway per AZ
#------------------------------------------------------------------------------
vpc_cidr           = "10.1.0.0/16"
azs                = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
private_subnets    = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
public_subnets     = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]
single_nat_gateway = false

#------------------------------------------------------------------------------
# Service — prod sizing: bigger tasks, one per AZ baseline, scale to 10
#------------------------------------------------------------------------------
container_image              = "public.ecr.aws/nginx/nginx:latest"
task_cpu                     = 512
task_memory                  = 1024
desired_count                = 3
min_capacity                 = 3
max_capacity                 = 10
cpu_target_utilization       = 60
enable_request_count_scaling = true
requests_per_target          = 500

health_check_grace_period_seconds  = 60
enable_circuit_breaker_rollback    = true
deployment_minimum_healthy_percent = 100
log_retention_in_days              = 30
enable_container_insights          = true

#------------------------------------------------------------------------------
# External dependencies — placeholders on purpose.
# `terraform plan` does not validate these; drop in the real replication
# group endpoint and security group ID before any apply.
#------------------------------------------------------------------------------
redis_endpoint          = "dummy.prod.cache.amazonaws.com"
redis_security_group_id = "sg-00000000000000000"

# Secret value intentionally not set here — see README (Secrets flow).
# app_secret_value = null
