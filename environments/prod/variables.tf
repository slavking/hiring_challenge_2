variable "aws_profile" {
  description = "AWS CLI profile for this environment"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
  default     = "app"
}

#------------------------------------------------------------------------------
# Network
#------------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "azs" {
  description = "Availability zones to span"
  type        = list(string)
}

variable "private_subnets" {
  description = "Private subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDRs, one per AZ"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true = one shared NAT (cheap, dev-style); false = one NAT per AZ (HA, prod-style)"
  type        = bool
}

#------------------------------------------------------------------------------
# Service
#------------------------------------------------------------------------------

variable "container_image" {
  description = "Container image to run"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
}

variable "desired_count" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "cpu_target_utilization" {
  type    = number
  default = 60
}

variable "enable_request_count_scaling" {
  type    = bool
  default = false
}

variable "requests_per_target" {
  type    = number
  default = 500
}

variable "health_check_grace_period_seconds" {
  type    = number
  default = 60
}

variable "enable_circuit_breaker_rollback" {
  type    = bool
  default = false
}

variable "deployment_minimum_healthy_percent" {
  type    = number
  default = 50
}

variable "log_retention_in_days" {
  type    = number
  default = 14
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# External dependencies
#------------------------------------------------------------------------------

variable "redis_endpoint" {
  description = "Primary endpoint of the existing ElastiCache Redis replication group (placeholder until apply)"
  type        = string
}

variable "redis_security_group_id" {
  description = "Security group ID of the existing Redis replication group (placeholder until apply)"
  type        = string
}

variable "app_secret_value" {
  description = "Optional initial secret value; normally left null and set out-of-band"
  type        = string
  default     = null
  sensitive   = true
}
