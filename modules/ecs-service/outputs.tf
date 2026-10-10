output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "app_security_group_id" {
  description = "Security group of the Fargate tasks"
  value       = aws_security_group.app.id
}

output "secret_arn" {
  description = "ARN of the app secret in Secrets Manager"
  value       = aws_secretsmanager_secret.this.arn
}
