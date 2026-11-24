# Anonymized excerpts from api-borg Terraform; illustrative, not deployable.

locals {
  replica_regions = [
    for region in var.ecr_replica_regions : region
    if region != var.aws_region
  ]
}

module "ecr" {
  source  = "terraform-aws-modules/ecr/aws"
  version = "2.4.0"

  repository_name                 = "${var.service_name}-${var.app_environment}"
  repository_image_tag_mutability = "MUTABLE"
  create_lifecycle_policy         = true
  repository_force_delete         = false

  repository_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent tagged images"
      selection = {
        tagStatus     = "tagged"
        tagPrefixList = ["v"]
        countType     = "imageCountMoreThan"
        countNumber   = var.keep_last_images
      }
      action = {
        type = "expire"
      }
    }]
  })

  tags = local.tags
}

resource "aws_ecr_replication_configuration" "replication" {
  count = length(local.replica_regions) > 0 ? 1 : 0

  replication_configuration {
    rule {
      dynamic "destination" {
        for_each = toset(local.replica_regions)

        content {
          region      = destination.key
          registry_id = module.ecr.repository_registry_id
        }
      }

      repository_filter {
        filter      = "${var.service_name}-${var.app_environment}"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
