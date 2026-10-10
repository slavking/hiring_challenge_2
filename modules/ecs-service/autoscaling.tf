resource "aws_appautoscaling_target" "ecs" {
  service_namespace  = "ecs"
  resource_id        = "service/${split("/", var.cluster_arn)[1]}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

# Baseline policy: CPU target tracking. Works with zero traffic and zero
# extra infrastructure. Its weakness for web apps is that CPU is a lagging
# proxy for offered load / latency.
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.environment}-${var.name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.cpu_target_utilization
  }
}

# Better web signal: scale directly on requests per task. Only possible
# because the service sits behind an ALB, and noisy at very low request
# rates — hence off by default, enabled in prod. When multiple target
# tracking policies exist, Application Auto Scaling scales out on whichever
# one demands more tasks.
resource "aws_appautoscaling_policy" "requests" {
  count = var.enable_request_count_scaling ? 1 : 0

  name               = "${var.environment}-${var.name}-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.this.arn_suffix}/${aws_lb_target_group.this.arn_suffix}"
    }
    target_value = var.requests_per_target
  }
}
