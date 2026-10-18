resource "google_compute_global_address" "website" {
  project = var.project_id
  name    = "${var.name}-ip"
}

resource "google_compute_backend_bucket" "website" {
  provider    = google-beta
  project     = var.project_id
  name        = "${var.name}-backend"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "USE_ORIGIN_HEADERS"
    negative_caching  = false
    serve_while_stale = 0
  }

  custom_response_headers = ["X-Content-Type-Options: nosniff"]
}

resource "google_compute_url_map" "website" {
  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_bucket.website.id

  host_rule {
    hosts        = ["*"]
    path_matcher = "website"
  }
  path_matcher {
    name            = "website"
    default_service = google_compute_backend_bucket.website.id
    path_rule {
      paths   = ["/"]
      service = google_compute_backend_bucket.website.id
      route_action {
        url_rewrite {
          path_prefix_rewrite = "/index.html"
        }
      }
    }
  }
}

resource "google_compute_target_http_proxy" "website" {
  project = var.project_id
  name    = "${var.name}-http"
  url_map = google_compute_url_map.website.id
}

resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name}-http"
  ip_address            = google_compute_global_address.website.address
  target                = google_compute_target_http_proxy.website.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
