# Resolved from the provider configuration locally — no AWS API call, so it is
# safe for `terraform plan` in any state.
data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.environment}/${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = var.tags
}
