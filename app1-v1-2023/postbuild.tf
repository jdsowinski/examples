# Anonymized excerpts from the original postbuild configuration; not deployable.

module "ecs_cluster" {
  source       = "terraform-aws-modules/ecs/aws//modules/cluster"
  version      = "5.12.1"
  cluster_name = "${var.application_name}-cluster"

  create_task_exec_iam_role             = false
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    "${var.application_name}-CapacityProvider" = {
      auto_scaling_group_arn         = module.autoscaling["${var.application_name}-CapacityProvider"].autoscaling_group_arn
      managed_termination_protection = "DISABLED"
      managed_scaling = {
        maximum_scaling_step_size = 1
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 100
      }
    }
  }

  tags = local.tags
}

module "ecs_service" {
  source      = "terraform-aws-modules/ecs/aws//modules/service"
  version     = "6.0.0"
  name        = "${var.application_name}-service"
  cluster_arn = module.ecs_cluster.arn
  cpu         = var.task_cpu
  memory      = var.task_memory

  capacity_provider_strategy = {
    "${var.application_name}-CapacityProvider" = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers["${var.application_name}-CapacityProvider"].name
      weight            = 1
      base              = 1
    }
  }

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = var.task_execution_role_arn
  requires_compatibilities  = ["EC2"]
  network_mode              = "bridge"
  container_definitions     = local.container_definitions

  ordered_placement_strategy = {
    binpack_cpu = {
      type  = "binpack"
      field = "cpu"
    }
  }

  load_balancer = {
    service = {
      target_group_arn = element(module.alb.target_group_arns, 0)
      container_name   = local.container_name
      container_port   = local.container_port
    }
  }

  subnet_ids         = data.aws_subnets.public_subnets.ids
  enable_autoscaling = false
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.application_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_scale_up_threshold
  dimensions = {
    ServiceName = "${var.application_name}-service"
    ClusterName = "${var.application_name}-cluster"
  }
  alarm_actions = [aws_appautoscaling_policy.scale_up.arn]
  tags          = local.tags
}

resource "aws_appautoscaling_policy" "scale_up" {
  name               = "${var.application_name}-scale-up"
  depends_on         = [aws_appautoscaling_target.service]
  service_namespace  = "ecs"
  resource_id        = "service/${module.ecs_cluster.name}/${module.ecs_service.name}"
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

resource "aws_appautoscaling_target" "service" {
  service_namespace  = "ecs"
  resource_id        = "service/${module.ecs_cluster.name}/${module.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_tasks
  max_capacity       = var.max_tasks
  tags               = local.tags
}
