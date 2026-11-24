# Anonymized GitHub Actions OIDC trust and deployment policy pattern.

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "github_actions" {
  name = "${var.application_name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repository}:ref:refs/heads/${var.development_branch}",
            "repo:${var.github_repository}:ref:refs/heads/${var.production_branch}",
          ]
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = local.default_tags
}

resource "aws_iam_policy" "github_deploy" {
  name        = "${var.application_name}-github-deploy"
  description = "Allow GitHub Actions to publish images and deploy the service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:UpdateService", "ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
        Resource = var.ecs_service_arns
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = var.task_role_arns
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"]
        Resource = var.ecr_repository_arns
      }
    ]
  })

  tags = local.default_tags
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_deploy.arn
}
