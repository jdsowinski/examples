# Anonymized task configuration pattern from api-borg Terraform.
# Keep nonsecret configuration in environment and secrets in SSM references.

locals {
  container_name = "${var.service_name}-${var.app_environment}"

  environment_variables = [
    { name = "APP_ENV", value = var.app_environment },
    { name = "LOG_LEVEL", value = var.log_level },
    { name = "API_BASE_URL", value = var.api_base_url },
    { name = "ASSETS_BUCKET", value = var.assets_bucket_name },
    { name = "ASSETS_REGION", value = var.aws_region },
  ]

  secret_variables = [
    {
      name      = "DATABASE_URI"
      valueFrom = "/${var.service_name}/${var.app_environment}/app/database_uri"
    },
    {
      name      = "UPSTREAM_API_TOKEN"
      valueFrom = "/${var.service_name}/${var.app_environment}/app/upstream_api_token"
    },
  ]

  container_definitions = {
    (local.container_name) = {
      image = data.aws_ecr_image.selected.image_uri
      port_mappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      environment              = local.environment_variables
      secrets                  = local.secret_variables
      readonly_root_filesystem = false
      health_check = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.healthcheck_endpoint} || exit 1"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 0
      }
    }
  }
}
