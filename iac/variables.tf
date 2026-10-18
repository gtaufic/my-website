variable "project_id" {
  description = "GCP project to deploy into, supplied through TF_VAR_project_id."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name format, supplied by the IaC workflow."
  type        = string
}

variable "github_repository_id" {
  description = "Numeric GitHub repository ID, supplied by the IaC workflow."
  type        = string
}

variable "github_repository_owner_id" {
  description = "Numeric GitHub owner ID, supplied by the IaC workflow."
  type        = string
}

variable "region" {
  description = "Bucket location. us-east1 is a low-cost, free-tier-eligible testing region."
  type        = string
  default     = "us-east1"
}

variable "environment" {
  description = "develop deploys dev; main deploys production."
  type        = string
  validation {
    condition     = contains(["dev", "production"], var.environment)
    error_message = "environment must be dev or production."
  }
}

variable "website_force_destroy" {
  description = "Allow deletion of a nonempty website bucket during explicit cleanup."
  type        = bool
  default     = false
}
