# ---------------------------------------------------------------
# Container image registry for the on-demand EKS/ArgoCD demo
#
# Lives in the persistent stack, not terraform/eks-demo/, because image
# builds are decoupled from cluster lifecycle: the demo cluster is
# destroyed nightly, but the image it deploys shouldn't need rebuilding
# every time a session spins back up.
# ---------------------------------------------------------------

resource "aws_ecr_repository" "demo_site" {
  name                 = "resume-site-demo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "demo_site" {
  repository = aws_ecr_repository.demo_site.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
