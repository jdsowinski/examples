# Anonymized excerpts from the original prebuild configuration; not deployable.

resource "aws_db_subnet_group" "database" {
  name        = "${var.application_name}-subnet-group"
  subnet_ids  = data.aws_subnets.public_subnets.ids
  description = "${var.application_name}-subnet-group"
  tags        = local.tags
}

module "database" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name            = "${var.application_name}-database"
  database_name   = var.database_name
  engine          = "aurora-mysql"
  engine_version  = var.database_engine_version
  master_username = var.database_master_username
  instances = {
    one = {
      instance_class      = var.database_instance_type
      publicly_accessible = true
    }
  }

  autoscaling_enabled      = true
  autoscaling_min_capacity = var.database_min_capacity
  autoscaling_max_capacity = var.database_max_capacity
  skip_final_snapshot      = true

  vpc_id                 = data.aws_vpc.vpc_id.id
  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.database.id]
  create_security_group  = false
  apply_immediately      = true
  tags                   = local.tags
}

module "container_registry" {
  source = "terraform-aws-modules/ecr/aws"

  repository_name                 = var.application_name
  repository_image_tag_mutability = "MUTABLE"
  create_lifecycle_policy         = true
  repository_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the most recent images"
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

  repository_force_delete = true
  tags                    = local.tags
}
