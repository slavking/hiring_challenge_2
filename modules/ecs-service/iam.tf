#------------------------------------------------------------------------------
# Execution role — used by the ECS agent itself (image pull, log streams,
# secret injection). This is where the Secrets Manager permission belongs,
# NOT on the task role.
#------------------------------------------------------------------------------

data "aws_iam_policy_document" "execution_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.environment}-${var.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json

  tags = var.tags
}

# Managed policy: ECR image pull + CloudWatch Logs.
resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    sid       = "ReadAppSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.this.arn]
  }

  # Only needed if the secret is encrypted with a customer-managed KMS key
  # (the default aws/secretsmanager key does not require this):
  #
  # statement {
  #   sid       = "DecryptAppSecret"
  #   actions   = ["kms:Decrypt"]
  #   resources = ["<cmk-arn>"]
  # }
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "read-app-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

#------------------------------------------------------------------------------
# Task role — used by the application code itself. No permissions today;
# add policies here when the app needs to call AWS APIs at runtime.
#------------------------------------------------------------------------------

resource "aws_iam_role" "task" {
  name               = "${var.environment}-${var.name}-task"
  assume_role_policy = data.aws_iam_policy_document.execution_assume.json

  tags = var.tags
}
