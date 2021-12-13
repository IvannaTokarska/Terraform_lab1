provider "google" {
  project     = "tokarska"
  region      = "europe-west1"
}

resource "google_storage_bucket" "terraform_state" {
  name = "ita-terraform-state-${random_integer.ri.result}"
  location = "EUROPE-WEST1"
  force_destroy = true
  # Enable versioning so we can see the full revision history of our
  # state files
  versioning {
    enabled = true
  }
}

resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

output "bucket_url" {
  value       = google_storage_bucket.terraform_state.url
  description = "The the URL of the bucket"
}