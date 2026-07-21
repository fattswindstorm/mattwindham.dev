# Cost-allocation tag activation has up to a 24h propagation delay in Cost
# Explorer/Budgets before this tag-scoped budget starts catching spend - the
# account-wide budget in terraform/billing-alert/main.tf is the real backstop
# during that window and afterward. Lives in this persistent stack (not the
# ephemeral cluster stack) since re-registering the cost allocation tag on
# every spin-up/teardown cycle would hit that 24h lag every single time.
resource "aws_ce_cost_allocation_tag" "project" {
  tag_key = "Project"
  status  = "Active"
}

resource "aws_budgets_budget" "eks_demo" {
  name         = "eks-demo-cost"
  budget_type  = "COST"
  limit_amount = "15"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = ["user:Project$eks-demo"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.billing_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.billing_alert_email]
  }

  depends_on = [aws_ce_cost_allocation_tag.project]
}
