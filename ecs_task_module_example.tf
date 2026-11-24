# Anonymized scheduled ECS task using the internal ECS task module.

module "scheduled_batch_task" {
  source  = "OTF_server.com/ORG/ecs-task/REDACTED"
  version = "2.1.0"

  task_name     = "batch-worker"
  vpc_id        = var.vpc_id
  launch_type   = "FARGATE"
  ecr_image_arn = module.ecr_repository.arn

  tags = {
    Project      = var.project
    Environment  = var.environment
    BusinessUnit = var.business_unit
    Application  = var.application
  }

  extra_tags = {
    CostCenter = var.cost_center
  }

  task_definition = {
    task_total_cpu = 1024
    task_total_mem = 2048
    subnet_ids     = var.private_subnet_ids

    containers = [{
      name    = "batch-worker"
      image   = "${module.ecr_repository.url}:${var.image_tag}"
      command = ["node", "dist/worker.js"]

      environment = [{
        name  = "APP_ENV"
        value = var.environment
      }]

      secrets = [{
        name      = "SERVICE_TOKEN"
        valueFrom = "/${var.project}/${var.application}/${var.environment}/service-token"
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-create-group  = "true"
          awslogs-group         = "/ecs/${var.project}-${var.application}-${var.environment}-batch-worker"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }]
  }

  schedules = [{
    name                = "daily"
    schedule_expression = "cron(0 3 * * ? *)"
    ecs_cluster_name    = var.ecs_cluster_name
  }]
}

output "batch_task_cicd_parameters" {
  value = {
    subnets        = module.scheduled_batch_task.cicd_ssm_subnets_param
    security_group = module.scheduled_batch_task.cicd_ssm_security_group_param
  }
}
