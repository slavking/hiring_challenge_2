# The secret is a resource, not a data source: a data source would make
# `terraform plan` fail when the secret does not exist yet.
resource "aws_secretsmanager_secret" "this" {
  name = "/${var.environment}/${var.name}/app-secret"

  # 0 = delete immediately. Convenient while experimenting, but there is no
  # recovery window — raise it (7-30) for anything you care about.
  recovery_window_in_days = 0

  tags = var.tags
}

# Only created when an initial value is passed in. Normally the value is set
# out-of-band after apply:
#   aws secretsmanager put-secret-value --profile <profile> \
#     --secret-id /<env>/<name>/app-secret --secret-string '...'
resource "aws_secretsmanager_secret_version" "this" {
  count = var.app_secret_value == null ? 0 : 1

  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.app_secret_value
}
