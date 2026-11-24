# Anonymized excerpts from api-borg Terraform; illustrative, not deployable.

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "5.12.1"

  cluster_name = "${var.service_name}-${var.app_environment}-cluster"

  create_task_exec_iam_role             = false
  default_capacity_provider_use_fargate = false
  autoscaling_capacity_providers = {
    "${var.service_name}-${var.app_environment}-capacity-provider" = {
      auto_scaling_group_arn = module.autoscaling[
        "${var.service_name}-${var.app_environment}-capacity-provider"
      ].autoscaling_group_arn
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

resource "aws_security_group" "ecs" {
  name        = "${var.service_name}-${var.app_environment}-ecs"
  description = "Application task network access"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [module.alb_security_group.security_group_id]
    description     = "Application traffic from the load balancer"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "5.12.1"

  name        = "${var.service_name}-${var.app_environment}"
  cluster_arn = module.ecs_cluster.arn
  cpu         = var.task_cpu
  memory      = var.task_memory

  capacity_provider_strategy = {
    "${var.service_name}-${var.app_environment}-capacity-provider" = {
      capacity_provider = module.ecs_cluster.autoscaling_capacity_providers[
        "${var.service_name}-${var.app_environment}-capacity-provider"
      ].name
      weight = 1
      base   = 1
    }
  }

  create_task_exec_iam_role = false
  task_exec_iam_role_arn    = var.task_execution_role_arn
  requires_compatibilities  = ["EC2"]
  network_mode              = "awsvpc"
  container_definitions     = local.container_definitions

  load_balancer = {
    application = {
      target_group_arn = element(module.alb.target_group_arns, 0)
      container_name   = local.container_name
      container_port   = var.container_port
    }
  }

  subnet_ids            = data.aws_subnets.private.ids
  create_security_group = false
  security_group_ids    = [aws_security_group.ecs.id]
  enable_autoscaling    = false
  tags                  = local.tags
}
