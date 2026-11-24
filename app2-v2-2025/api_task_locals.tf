# Anonymized ECS task environment and secret references; illustrative only.

locals {
  application_name = var.application_name
  service_family   = "${var.application_name}-${var.environment}"

  environment_variables = [
    { name = "APP_ENV", value = var.environment },
    { name = "LOG_LEVEL", value = var.log_level },
    { name = "UPSTREAM_API_URL", value = var.upstream_api_url },
    { name = "ASSETS_BUCKET", value = var.asset_bucket_name },
    { name = "ASSETS_REGION", value = var.aws_region },
  ]

  secret_variables = [
    {
      name      = "DATABASE_URI"
      valueFrom = "${var.parameter_arn_prefix}/database_uri"
    },
    {
      name      = "UPSTREAM_API_TOKEN"
      valueFrom = "${var.parameter_arn_prefix}/upstream_api_token"
    },
  ]

  container_definitions = [{
    name      = local.application_name
    image     = "${module.ecr_repository.url}:${var.image_tag}"
    cpu       = var.task_cpu
    memory    = var.task_memory
    essential = true

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
      appProtocol   = "http"
    }]

    command     = ["node", var.application_entrypoint]
    environment = local.environment_variables
    secrets     = local.secret_variables

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.healthcheck_path} || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }
  }]
}
