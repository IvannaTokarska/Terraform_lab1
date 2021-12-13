#!/bin/bash
sudo apt-get update
sudo apt-get install -y apache2
echo "Hello, World!" | sudo tee /var/www/html/index.html
sudo systemctl restart apache2

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
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }

  tags = ["allow-http"]

  metadata_startup_script = file("data.sh")
}