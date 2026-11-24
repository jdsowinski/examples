# Anonymized ECS service scaling pattern from api-borg Terraform.

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.service_name}-${var.app_environment}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_up_threshold
  dimensions = {
    ServiceName = "${var.service_name}-${var.app_environment}"
    ClusterName = "${var.service_name}-${var.app_environment}-cluster"
  }
  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
  tags          = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.service_name}-${var.app_environment}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_down_threshold
  dimensions = {
    ServiceName = "${var.service_name}-${var.app_environment}"
    ClusterName = "${var.service_name}-${var.app_environment}-cluster"
  }
  alarm_actions = [aws_appautoscaling_policy.scale_down.arn]
  tags          = local.tags
}

resource "aws_appautoscaling_target" "service" {
  service_namespace  = "ecs"
  resource_id        = "service/${module.ecs_cluster.name}/${module.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks
  tags               = local.tags
}

resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.service_name}-${var.app_environment}-scale-up"
  depends_on         = [aws_appautoscaling_target.service]
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "scale_down" {
  name               = "${var.service_name}-${var.app_environment}-scale-down"
  depends_on         = [aws_appautoscaling_target.service]
  service_namespace  = "ecs"
  resource_id        = aws_appautoscaling_target.service.resource_id
  scalable_dimension = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}
