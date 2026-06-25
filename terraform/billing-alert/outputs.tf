output "budget_name" {
  description = "Name of the AWS Budget tracking monthly account cost"
  value       = aws_budgets_budget.monthly_cost.name
}
