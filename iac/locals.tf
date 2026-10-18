locals {
  deployment_branch = var.environment == "dev" ? "develop" : "main"
  state_bucket_name = {
    dev        = "my-website-iac-state-dev"
    production = "my-website-iac-state-production"
  }[var.environment]
}
