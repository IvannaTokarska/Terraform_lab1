provider "google" {
  project     = "tokarska"
  region      = "europe-west1"
}

resource "google_compute_instance" "example" {
  name         = "example"
  machine_type = "f1-micro"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = data.google_compute_network.example-net.name

    access_config {
      // Ephemeral IP
    }
  }

  tags = ["allow-http"]

  metadata_startup_script = file("data.sh")
}

resource "google_compute_firewall" "example" {
  name    = "terraform-example-firewall"
  network = data.google_compute_network.example-net.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["allow-http"]
}

# resource "google_compute_instance" "example" {
#   name         = "example"
#   machine_type = "f1-micro"
#   zone         = "europe-west1-b"

#   boot_disk {
#     initialize_params {
#       image = "debian-cloud/debian-10"
#     }
#   }

#   network_interface {
#     network = "default"

#     access_config {
#       // Ephemeral IP
#     }
#   }

#   tags = ["allow-http"]
# }

# resource "google_compute_firewall" "example" {
#   name    = "terraform-example-firewall"
#   network = "default"

#   allow {
#     protocol = "tcp"
#     ports    = ["80"]
#   }
  
#   source_tags = [ "web" ]
#   target_tags = ["allow-http"]
# }

data "google_compute_network" "example-net" {
  name = "default"
}

resource "google_compute_instance_template" "example" {
  name         = "example"
  machine_type = "f1-micro"

  disk {
    source_image = "debian-cloud/debian-10"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = data.google_compute_network.example-net.name
    access_config {
      // Ephemeral IP
    }
  }

  tags = ["allow-http"]

  metadata_startup_script = file("data.sh")

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_group_manager" "example" {
  name               = "example"
  base_instance_name = "example"
  zone               = "europe-west1-b"
  target_size        = "2"
  version {
    instance_template  = google_compute_instance_template.example.id
  }
}

resource "google_compute_autoscaler" "example" {
  name   = "example"
  zone   = "europe-west1-b"
  target = google_compute_instance_group_manager.example.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}

resource "google_compute_region_backend_service" "example" {
  load_balancing_scheme = "EXTERNAL"
  backend {
    group               = google_compute_instance_group_manager.example.instance_group
    balancing_mode      = "CONNECTION"
  }

  region                = "europe-west1"
  name                  = "web-backend"
  protocol              = "TCP"
  timeout_sec           = 10
  health_checks         = [google_compute_region_health_check.example.id]
}

resource "google_compute_region_health_check" "example" {
  name                  = "example-check"
  check_interval_sec    = 1
  timeout_sec           = 1
  region                = "europe-west1"

  tcp_health_check {
    port                = var.server_port
  }
}

resource "google_compute_forwarding_rule" "example" {
  name                  = "example-forwarding-rule"
  region                = "europe-west1"
  port_range            = var.server_port
  backend_service       = google_compute_region_backend_service.example.id
}

terraform {
  backend "gcs" {
    # Replace this with your bucket name!
    bucket         = "ita-terraform-state-83423"
    prefix         = "prod/state"
  }
}