# Adopt the authentication resources created by scripts/terraform-init.
import {
  to = google_iam_workload_identity_pool.github
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/${local.name}-github"
}

import {
  to = google_iam_workload_identity_pool_provider.github
  id = "projects/${var.project_id}/locations/global/workloadIdentityPools/${local.name}-github/providers/github"
}

import {
  to = google_service_account.iac
  id = "projects/${var.project_id}/serviceAccounts/${local.name}-iac@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${local.name}-github"
  display_name              = "GitHub ${var.environment}"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub Actions"

  attribute_mapping = {
    "google.subject"                = "assertion.sub"
    "attribute.repository_id"       = "assertion.repository_id"
    "attribute.repository_owner_id" = "assertion.repository_owner_id"
    "attribute.ref"                 = "assertion.ref"
    "attribute.workflow_ref"        = "assertion.workflow_ref"
    "attribute.plan_workflow"       = "assertion.event_name == 'pull_request' ? assertion.workflow_ref.extract('{path}@') : ''"
  }

  # Environment subjects alone do not prove the branch. Check both claims and
  # the repository's immutable IDs. PRs must target this environment's branch;
  # only the read-only plan account accepts their workflow identity.
  attribute_condition = join(" && ", [
    "assertion.repository_id == '${var.github_repository_id}'",
    "assertion.repository_owner_id == '${var.github_repository_owner_id}'",
    "((assertion.ref == 'refs/heads/${local.deployment_branch}' && assertion.event_name in ['push', 'workflow_dispatch']) || (assertion.event_name == 'pull_request' && assertion.base_ref == '${local.deployment_branch}' && assertion.ref.startsWith('refs/pull/') && assertion.ref.endsWith('/merge')))",
    "assertion.sub.endsWith(':environment:${var.environment}')",
  ])

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "iac" {
  project      = var.project_id
  account_id   = "${local.name}-iac"
  display_name = "GitHub IaC (${var.environment})"
}

resource "google_service_account" "website" {
  project      = var.project_id
  account_id   = "${local.name}-web"
  display_name = "GitHub website (${var.environment})"
}

# PR code gets read access only, even if it changes the plan command.
resource "google_service_account" "plan" {
  project      = var.project_id
  account_id   = "${local.name}-plan"
  display_name = "GitHub Terraform plan (${var.environment})"
}

resource "google_service_account_iam_member" "plan_federation" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.plan_workflow/${var.github_repository}/.github/workflows/iac.yml"
}

resource "google_project_iam_member" "plan" {
  for_each = toset([
    "roles/viewer",
    "roles/iam.securityReviewer",
    "roles/serviceusage.serviceUsageConsumer",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.plan.email}"
}

resource "google_storage_bucket_iam_member" "plan_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.plan.email}"
}

locals {
  github_workflow_principal = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.workflow_ref/${var.github_repository}/.github/workflows"
  # Project-scoped roles are required to CREATE resources and manage this root's
  # IAM. No Owner/Editor or private keys. projectIamAdmin is privileged: protect
  # develop/main and review IAM changes (see README).
  iac_roles = toset([
    "roles/compute.loadBalancerAdmin",
    "roles/iam.roleAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageConsumer",
    "roles/storage.admin",
  ])
}

resource "google_service_account_iam_member" "iac_federation" {
  service_account_id = google_service_account.iac.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_workflow_principal}/iac.yml@refs/heads/${local.deployment_branch}"
}

resource "google_service_account_iam_member" "website_federation" {
  service_account_id = google_service_account.website.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.github_workflow_principal}/website.yml@refs/heads/${local.deployment_branch}"
}

resource "google_project_iam_member" "iac" {
  for_each = local.iac_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.iac.email}"
}

resource "google_storage_bucket_iam_member" "iac_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.iac.email}"
}

resource "google_storage_bucket_iam_member" "website_content" {
  bucket = module.static_website.bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.website.email}"
}

resource "google_project_iam_custom_role" "cdn_invalidator" {
  project     = var.project_id
  role_id     = "website_${var.environment}_cdn_invalidator"
  title       = "Website CDN invalidation (${var.environment})"
  description = "Read the frontend IP, invalidate CDN content, and wait for the operation."
  permissions = [
    "compute.globalOperations.get",
    "compute.globalAddresses.get",
    "compute.urlMaps.get",
    "compute.urlMaps.invalidateCache",
    "serviceusage.services.use",
  ]
}

resource "google_project_iam_member" "website_cdn" {
  project = var.project_id
  role    = google_project_iam_custom_role.cdn_invalidator.name
  member  = "serviceAccount:${google_service_account.website.email}"
}
