provider "google" {
  project  = "tokarska"
  region  = "europe-west1"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  subnet_mode = "custom"
  mtu = 1460 
  bgp_routing_mode = "regional"
}

resource "google_compute_network_subnet" "private_subnet_1" {
  network = google_compute_network.vpc_network.id
  range = "10.0.1.0/24"
  region = "europe-west1"
}

resource "google_compute_network_subnet" "private_subnet_2" {
  network = google_compute_network.vpc_network.id
  range = "10.0.2.0/24"
  region = "europe-west1"
}

resource "google_compute_forwarding_rule" "allow_internal_private" {

  allow {
      protocol = ["TCP:1-65535", "UDP:1-65535", "ICMP"]
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

resource "google_compute_forwarding_rule" "allow_lb_health" {

  direction = "INGRESS" 
  action = "allow" 
  rules = 80 
  target_tags = ["allow-healthcheck"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "209.85.152.0/22", "209.85.204.0/22"]
  network = google_compute_network.vpc_network.id
}

resource "google_compute_forwarding_rule" "allow_http" {

  direction = "INGRESS" 
  action = "allow" 
  rules = 80 
  target_tags = ["allow-http"] 
  network = google_compute_network.vpc_network.id
}

resource "google_compute_forwarding_rule" "allow_ssh_ingress_from_iap" {

  direction = "INGRESS" 
  action = "allow" 
  rules = 22
  source_ranges = "35.235.240.0/20"
  target_tags = ["allow-ssh"] 
  network = google_compute_network.vpc_network.id
}

resource "google_compute_instance_templates" "backend_template" {
  region = "europe-west1"
  network = google_compute_network.vpc_network.id
  subnet = "private_subnet_2"
  tags = ["allow-ssh", "allow-healthcheck"] 
  image_family = "debian-10"
  image_project = "debian-cloud" 
  disk {
      boot = true
      size = 10
  } 
  machine_type = "f1-micro"
}

resource "google_compute_instance_group_managed" "backend_mig" {
  
  template = "backend_template" 
  size = 2
  zone = ["europe-west1-b", "europe-west1-c"]
  region = "europe-west1"
}

resource "google_compute_health_checks" "backend_check" {
  port = 80
}

resource "google_compute_backend_services" "backend_bs" {
  protocol = "TCP"
  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.vpc_network.id
  health_checks = google_compute_health_checks.backend_check.id
  region = "europe-west1"

  backend {
      group = google_compute_instance_group_manager.backend_mig.instance_group
      region = "europe-west1" 
      balancing_mode = "CONNECTION"
  }
 
}

resource "google_compute_forwarding_rule" "backend_lb" {

  load_balancing_scheme = "INTERNAL"
  network = google_compute_network.vpc_network.id
  subnet = "private-subnet-2"
  ip_protocol = "TCP" 
  region = "europe-west1"
}

resource "google_compute_instance_templates" "frontend_template" {
  region = "europe-west1"
  network = google_compute_network.vpc_network.id
  subnet = "private_subnet_1"
  tags = ["allow-ssh", "allow-healthcheck", "allow-http"] 
  image_family = "centos-7"
  image_project = "centos-cloud" 
  disk {
      boot = true
      size = 20
  } 
  machine_type = "f1-micro"
}

resource "google_compute_instance_group_managed" "frontend_mig" {
  
  template = "frontend_template" 
  size = 2
  zones = ["europe-west1-b", "europe-west1-c"]
  region = "europe-west1"
}

resource "google_compute_health_checks" "frontend_check" {
  port = 80
}

resource "google_compute_backend_services" "frontend_bs" {
  protocol = "HTTP"
  port_name = "http"
  health_checks = google_compute_health_checks.frontend_check.id

  backend {
      group = google_compute_instance_group_manager.frontend_mig.instance_group
      region = "europe-west1" 
      balancing_mode = "RATE"
      max_rate_per_instance = 100
      capacity_scaler = 0.8
  }

}