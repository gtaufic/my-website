variable "project_id" { type = string }
variable "name" { type = string }
variable "bucket_name" { type = string }
variable "location" { type = string }
variable "labels" { type = map(string) }
variable "force_destroy" {
  type    = bool
  default = false
}
