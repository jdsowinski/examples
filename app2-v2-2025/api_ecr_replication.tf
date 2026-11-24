# Anonymized ECR and cross-region replication pattern; illustrative only.

module "ecr_repository" {
  source  = "registry.example.invalid/acme/ecr-registry/aws"
  version = "1.3.0"

  registry_name = "${var.application_name}/${var.environment}"
  tags          = local.default_tags

  use_custom_policy = true
  custom_policy_json = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Retain a bounded number of images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.image_retention_count
      }
      action = {
        type = "expire"
      }
    }]
  })

  replication_destinations = [
    for region in var.replication_regions : {
      region = region
    }
  ]

  replication_repository_filters = [{
    filter      = "${var.application_name}/${var.environment}"
    filter_type = "PREFIX_MATCH"
  }]
}
