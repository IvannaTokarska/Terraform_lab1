provider "google" {
  project  = "tokarska"
  region  = "europe-west1"
}

resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
  mtu = 1460 
  auto_create_subnetworks = false
  project = "tokarska"
  routing_mode = "regional"
}

resource "google_compute_network_subnet" "private_subnet_1" {
  name = "private-subnet-1"
  network = google_compute_network.vpc_network.id
  ip_cidr_range = "10.0.1.0/24"
  region = "europe-west1"
}

resource "google_compute_network_subnet" "private_subnet_2" {
  name = "private-subnet-2"
  network = google_compute_network.vpc_network.id
  ip_cidr_range = "10.0.2.0/24"
  region = "europe-west1"
}

resource "google_compute_forwarding_rule" "allow_internal_private" {
  
  name    = "allow-internal-private"
  allow {
    protocol = "ICMP"
  }

  allow {
    protocol = "TCP"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "UDP"
    ports    = ["1-65535"]
  }

  source_ranges = ["10.0.1.0/24", "10.0.2.0/24"]
  network = google_compute_network.vpc_network.id
  priority = 65534
}

resource "google_compute_forwarding_rule" "default_allow_icmp" {

  allow {
    protocol = "ICMP"
  } 
  network = google_compute_network.vpc_network.id
  priority = 65534
}

resource "google_compute_forwarding_rule" "allow_ssh_ingress_from_iap" {

  name    = "allow-ssh-ingress-from-iap"
  direction = "INGRESS" 
  allow {
    protocol = "TCP"
    ports    = ["22"]
  }
  source_ranges = "35.235.240.0/20"
  target_tags = ["allow-ssh"] 
  network = google_compute_network.vpc_network.id
}

resource "google_compute_instance_templates" "backend_template" {
  
  name = "backend-template"
  region = "europe-west1"
  network = google_compute_network.vpc_network.id
  network_interface {
    subnetwork = "private-subnet-2"
  }
  tags = ["allow-ssh", "no-ip"] 
  boot_disk {
    initialize_params {
      image = "debian-10/debian-cloud"
    }
  }
  machine_type = "f1-micro"
}

resource "google_compute_instance_group_managed" "backend_mig" {
  
  name = "backend-mig"
  template = "backend_template" 
  size = 2
  zone = ["europe-west1-b", "europe-west1-c"]
  region = "europe-west1"
}

resource "google_compute_backend_services" "backend_bs" {
  
  name = "backend-bs"
  protocol = "TCP"
  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.vpc_network.id
  region = "europe-west1"

  backend {
      group = google_compute_instance_group_manager.backend_mig.instance_group
      region = "europe-west1" 
      balancing_mode = "CONNECTION"
  }
 
}

resource "google_compute_forwarding_rule" "backend_lb" {

  name = "backend-lb"
  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.vpc_network.id
  network_interface {
    subnetwork = "private-subnet-2"
  }
  subnet = "private-subnet-2"
  ip_protocol = "TCP" 
  region = "europe-west1"
}

resource "google_compute_instance_templates" "frontend_template" {
  
  name = "frontend-template"
  region = "europe-west1"
  network = google_compute_network.vpc_network.id
  network_interface {
    subnetwork = "private-subnet-1"
  }
  tags = ["allow-ssh", "allow-healthcheck", "allow-http"] 
  boot_disk {
    initialize_params {
      image = "centos-7/centos-cloud"
    }
  }
  machine_type = "f1-micro"
}

resource "google_compute_instance_group_managed" "frontend_mig" {
  
  name = "frontend-mig"
  template = "frontend_template" 
  size = 2
  zones = ["europe-west1-b", "europe-west1-c"]
  region = "europe-west1"
}

resource "google_compute_backend_services" "frontend_bs" {
  
  name = "frontend-bs"
  protocol = "HTTP"
  port_name = "http"

  backend {
      group = google_compute_instance_group_manager.frontend_mig.instance_group
      region = "europe-west1" 
      balancing_mode = "RATE"
      max_rate_per_instance = 100
      capacity_scaler = 0.8
  }

}