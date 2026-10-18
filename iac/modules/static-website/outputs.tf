output "bucket_name" {
  value = google_storage_bucket.website.name
}
output "url_map_name" {
  value = google_compute_url_map.website.name
}
output "ip_address" {
  value = google_compute_global_address.website.address
}
output "website_url" {
  value = "http://${google_compute_global_address.website.address}"
}
