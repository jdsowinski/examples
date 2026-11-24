# Anonymized ECS API service pattern; illustrative only.

module "ecs_service" {
  source  = "registry.example.invalid/acme/ecs-service/aws"
  version = "3.4.0"

  ecs_cluster_name         = var.cluster_name
  service_name             = local.application_name
  vpc_id                   = var.vpc_id
  service_subnet_ids       = var.private_subnet_ids
  load_balancer_subnet_ids = var.public_subnet_ids
  tags                     = local.default_tags

  only_create_target_group = true
  existing_listener_arn    = var.https_listener_arn
  target_group_port        = var.container_port

  additional_service_security_group_ids = [var.load_balancer_security_group_id]

  service_connect_configuration = {
    enable                       = true
    discovery_http_namespace_arn = var.service_discovery_namespace_arn
    allowed_security_group_ids   = var.client_security_group_ids
    services = [{
      port_name      = "${local.application_name}-${var.container_port}"
      discovery_name = "${local.application_name}-${var.environment}"
      client_aliases = [{
        port     = var.container_port
        dns_name = "${local.application_name}-${var.environment}"
      }]
    }]
  }

  load_balancer_params = {
    listener_rule_priority = var.listener_rule_priority
    listener_conditions = [{
      host_header  = var.hostnames
      path_pattern = null
    }]
    health_check = {
      healthy_threshold   = 2
      unhealthy_threshold = 5
      interval            = 10
      timeout             = 5
      matcher             = "200"
      path                = var.healthcheck_path
    }
  }

  autoscaling_configuration = {
    min_tasks = var.min_tasks
    max_tasks = var.max_tasks
    scaling_metrics = {
      high_cpu = {
        agg_period_in_sec       = 60
        threshold_in_percentage = var.cpu_scale_out_threshold
        watch_over_last_in_min  = 5
      }
      low_cpu = {
        agg_period_in_sec       = 60
        threshold_in_percentage = var.cpu_scale_in_threshold
        watch_over_last_in_min  = 10
      }
      high_memory = {
        agg_period_in_sec       = 60
        threshold_in_percentage = var.memory_scale_out_threshold
        watch_over_last_in_min  = 5
      }
    }
  }

  task_definition = {
    family         = local.service_family
    task_total_cpu = var.task_cpu
    task_total_mem = var.task_memory
    containers     = local.container_definitions

    execution_role_additional = {
      inline_policies = [{
        name = "RuntimeReferences"
        content = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["ssm:GetParameter", "ssm:GetParameters"]
              Resource = "${var.parameter_arn_prefix}/*"
            },
            {
              Effect   = "Allow"
              Action   = ["ecr:GetAuthorizationToken"]
              Resource = "*"
            },
            {
              Effect   = "Allow"
              Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage"]
              Resource = module.ecr_repository.arn
            }
          ]
        })
      }]
    }

    task_role_additional = {
      inline_policies = [{
        name = "ApplicationAssetAccess"
        content = jsonencode({
          Version = "2012-10-17"
          Statement = [
            {
              Effect   = "Allow"
              Action   = ["s3:ListBucket"]
              Resource = var.asset_bucket_arn
            },
            {
              Effect   = "Allow"
              Action   = ["s3:GetObject", "s3:PutObject"]
              Resource = "${var.asset_bucket_arn}/*"
            }
          ]
        })
      }]
    }
  }
}
