output "project_id" {
  value = var.project_id
}

output "project_number" {
  value = data.google_project.current.number
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "iac_service_account" {
  value = google_service_account.iac.email
}

output "website_service_account" {
  value = google_service_account.website.email
}

output "website_bucket" {
  value = module.static_website.bucket_name
}

output "cdn_url_map" {
  value = module.static_website.url_map_name
}

output "website_ip" {
  value = module.static_website.ip_address
}

output "website_url" {
  value = module.static_website.website_url
}
