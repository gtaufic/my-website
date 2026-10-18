terraform {
  backend "gcs" {}
}

# The backend bucket must exist BEFORE init. Adopt the CLI-created bucket into
# Terraform during the first apply; subsequent runs don't re-import it.
import {
  to = google_storage_bucket.state
  id = local.state_bucket_name
}

resource "google_storage_bucket" "state" {
  project                     = var.project_id
  name                        = local.state_bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      days_since_noncurrent_time = 30
      num_newer_versions         = 10
      with_state                 = "ARCHIVED"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
