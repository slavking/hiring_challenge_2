#------------------------------------------------------------------------------
# Security groups
#------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.environment}-${var.name}-alb"
  description = "Ingress to the ${var.name} ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  tags = merge(var.tags, { Name = "${var.environment}-${var.name}-alb" })
}

# Separate rule resource: an inline egress rule referencing the app SG would
# create a dependency cycle between the two security groups.
resource "aws_security_group_rule" "alb_to_app" {
  type                     = "egress"
  description              = "To app tasks"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.app.id
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
}

resource "aws_security_group" "app" {
  name        = "${var.environment}-${var.name}-app"
  description = "Fargate tasks of the ${var.name} service"
  vpc_id      = var.vpc_id

  ingress {
    description     = "From ALB only"
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Tasks need outbound access for: image pull via NAT, Secrets Manager,
  # CloudWatch Logs, and the Redis replication group.
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.environment}-${var.name}-app" })
}

# The only Redis-adjacent resource: authorize the app tasks to reach the
# existing replication group. Security groups are stateful, so reply traffic
# is allowed automatically. The Redis SG is referenced by raw ID, so
# `terraform plan` never fails even if the group does not exist yet.
resource "aws_security_group_rule" "redis_ingress" {
  type                     = "ingress"
  description              = "Redis from ${var.environment}-${var.name} app tasks"
  security_group_id        = var.redis_security_group_id
  source_security_group_id = aws_security_group.app.id
  from_port                = var.redis_port
  to_port                  = var.redis_port
  protocol                 = "tcp"
}

#------------------------------------------------------------------------------
# Load balancer
#------------------------------------------------------------------------------

resource "aws_lb" "this" {
  name               = "${var.environment}-${var.name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = "${var.environment}-${var.name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # required for awsvpc network mode

  health_check {
    path    = "/"
    matcher = "200-399" # slack for a dummy image that doesn't return plain 200
  }

  tags = var.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

#------------------------------------------------------------------------------
# Task definition and service
#------------------------------------------------------------------------------

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.environment}-${var.name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "APP_ENV", value = var.environment },
        { name = "REDIS_HOST", value = var.redis_endpoint },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
      ]

      # Injected by the ECS agent at task start using the execution role.
      secrets = [
        { name = "APP_SECRET", valueFrom = aws_secretsmanager_secret.this.arn }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  deployment_circuit_breaker {
    enable   = true
    rollback = var.enable_circuit_breaker_rollback
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.name
    container_port   = var.container_port
  }

  # Application Auto Scaling owns the desired count after creation; without
  # this every plan would try to reset the count back to var.desired_count.
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = var.tags
}
