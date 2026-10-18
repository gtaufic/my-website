locals {
  name = "my-website-${var.environment}"
  labels = {
    application = "my-website"
    environment = var.environment
    managed_by  = "terraform"
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

module "static_website" {
  source = "./modules/static-website"
  providers = {
    google      = google
    google-beta = google-beta
  }

  project_id    = var.project_id
  name          = local.name
  bucket_name   = "${var.project_id}-${var.environment}-web"
  location      = var.region
  labels        = local.labels
  force_destroy = var.website_force_destroy
}
