variable "name" {
  description = "Service name, used as a prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. prod, dev)"
  type        = string
}

variable "cluster_arn" {
  description = "ARN of the ECS cluster the service runs in"
  type        = string
}

variable "vpc_id" {
  description = "VPC the service, ALB and security groups live in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the Fargate tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for the ALB"
  type        = list(string)
}

variable "alb_ingress_cidrs" {
  description = "CIDRs allowed to reach the ALB on port 80"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "container_image" {
  description = "Container image to run (e.g. public.ecr.aws/nginx/nginx:latest)"
  type        = string
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
}

variable "desired_count" {
  description = "Initial number of tasks (owned by autoscaling after creation)"
  type        = number
}

variable "min_capacity" {
  description = "Minimum task count for autoscaling"
  type        = number
}

variable "max_capacity" {
  description = "Maximum task count for autoscaling"
  type        = number
}

variable "cpu_target_utilization" {
  description = "Target average CPU utilization (%) for target-tracking scaling"
  type        = number
  default     = 60
}

variable "enable_request_count_scaling" {
  description = "Also scale on ALB request count per target (better web signal, needs meaningful traffic)"
  type        = bool
  default     = false
}

variable "requests_per_target" {
  description = "Target requests per task per minute when request-count scaling is enabled"
  type        = number
  default     = 500
}

variable "redis_endpoint" {
  description = "Primary endpoint of the existing ElastiCache Redis replication group"
  type        = string
}

variable "redis_port" {
  description = "Port of the Redis replication group"
  type        = number
  default     = 6379
}

variable "redis_security_group_id" {
  description = "Security group ID of the existing Redis replication group; the module adds an ingress rule allowing this service to reach it"
  type        = string
}

variable "app_secret_value" {
  description = "Optional initial value for the app secret. Leave null to manage the value out-of-band (aws secretsmanager put-secret-value)"
  type        = string
  default     = null
  sensitive   = true
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS waits before counting failed ALB health checks against a new task"
  type        = number
  default     = 60
}

variable "enable_circuit_breaker_rollback" {
  description = "Automatically roll back to the last COMPLETED deployment when the deployment circuit breaker trips"
  type        = bool
  default     = false
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower bound on healthy tasks during a deployment (100 = never drop below desired)"
  type        = number
  default     = 50
}

variable "deployment_maximum_percent" {
  description = "Upper bound on tasks during a deployment"
  type        = number
  default     = 200
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention for the service logs"
  type        = number
  default     = 14
}

variable "tags" {
  description = "Tags applied to all module resources"
  type        = map(string)
  default     = {}
}
