output "alb_dns_name" {
  description = "Public DNS name of the service ALB"
  value       = module.app.alb_dns_name
}

output "service_name" {
  description = "Name of the ECS service"
  value       = module.app.service_name
}

output "secret_arn" {
  description = "ARN of the app secret — set its value with: aws secretsmanager put-secret-value --profile <profile> --secret-id <this-arn> --secret-string '...'"
  value       = module.app.secret_arn
}
