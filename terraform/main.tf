terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "tourism-app-migration"
  region  = "europe-west1"
}

# Artifact Registry
resource "google_artifact_registry_repository" "tourism_images" {
  location      = "europe-west1"
  repository_id = "tourism-images"
  format        = "DOCKER"
  description   = "Docker images for tourism microservices"
}

# Cloud SQL
resource "google_sql_database_instance" "stakeholders_db" {
  name             = "stakeholders-db"
  database_version = "POSTGRES_18"
  region           = "europe-west1"

  settings {
    tier = "db-f1-micro"
  }

  deletion_protection = true
}

# NATS VM static IP
resource "google_compute_address" "nats_static_ip" {
  name    = "nats-static-ip"
  region  = "us-central1"
  address = "34.60.71.242"
}

# NATS VM
resource "google_compute_instance" "nats_vm" {
  name                      = "nats-vm"
  machine_type              = "e2-micro"
  zone                      = "us-central1-a"
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-13"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.nats_static_ip.address
    }
  }
}

# Secret Manager
resource "google_secret_manager_secret" "jwt_secret" {
  secret_id = "jwt-secret"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "mongodb_uri" {
  secret_id = "mongodb-uri"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "mongodb_uri_blog" {
  secret_id = "mongodb-uri-blog"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "mongodb_uri_payment" {
  secret_id = "mongodb-uri-payment"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "mongodb_uri_tours" {
  secret_id = "mongodb-uri-tours"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "neo4j_password" {
  secret_id = "neo4j-password"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "postgres_password" {
  secret_id = "postgres-password"
  replication {
    auto {}
  }
}

# Cloud Run - api-gateway
resource "google_cloud_run_v2_service" "api_gateway" {
  name     = "api-gateway"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/api-gateway:v9"

      env {
        name  = "GRPC_TLS_ENABLED"
        value = "true"
      }
      env {
        name  = "STAKEHOLDERS_SERVICE_URL"
        value = "https://stakeholders-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "BLOG_SERVICE_URL"
        value = "https://blog-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "TOUR_SERVICE_URL"
        value = "https://tour-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "TOUR_SERVICE_GRPC_URL"
        value = "tour-service-686574767001.europe-west1.run.app:443"
      }
      env {
        name  = "FOLLOWER_SERVICE_URL"
        value = "https://follower-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "FOLLOWER_SERVICE_GRPC_URL"
        value = "follower-service-686574767001.europe-west1.run.app:443"
      }
      env {
        name  = "PAYMENT_SERVICE_URL"
        value = "https://payment-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "PAYMENT_SERVICE_GRPC_URL"
        value = "payment-service-686574767001.europe-west1.run.app:443"
      }
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = "jwt-secret"
            version = "latest"
          }
        }
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = "https://tourism-app-migration.web.app"
      }
    }
  }
}

# Cloud Run - blog-service
resource "google_cloud_run_v2_service" "blog_service" {
  name     = "blog-service"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/blog-service:v2"

      env {
        name  = "SERVER_PORT"
        value = "8080"
      }
      env {
        name  = "FOLLOWER_SERVICE_URL"
        value = "https://follower-service-686574767001.europe-west1.run.app"
      }
      env {
        name  = "APP_BASE_URL"
        value = "https://blog-service-686574767001.europe-west1.run.app"
      }
      env {
        name = "SPRING_DATA_MONGODB_URI"
        value_source {
          secret_key_ref {
            secret  = "mongodb-uri-blog"
            version = "latest"
          }
        }
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = "https://tourism-app-migration.web.app"
      }
    }
  }
}

# Cloud Run - follower-service
resource "google_cloud_run_v2_service" "follower_service" {
  name     = "follower-service"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/follower-service:v3"

      ports {
        name           = "h2c"
        container_port = 8084
      }

      env {
        name  = "NEO4J_URI"
        value = "neo4j+s://32771365.databases.neo4j.io"
      }
      env {
        name  = "NEO4J_USER"
        value = "32771365"
      }
      env {
        name = "NEO4J_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = "neo4j-password"
            version = "latest"
          }
        }
      }
    }
  }
}

# Cloud Run - payment-service
resource "google_cloud_run_v2_service" "payment_service" {
  name     = "payment-service"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/payment-service:v1"

      ports {
        name           = "h2c"
        container_port = 8086
      }

      env {
        name = "MONGODB_URI"
        value_source {
          secret_key_ref {
            secret  = "mongodb-uri-payment"
            version = "latest"
          }
        }
      }
      env {
        name  = "NATS_URL"
        value = "nats://${google_compute_address.nats_static_ip.address}:4222"
      }
      env {
        name  = "TOUR_SERVICE_URL"
        value = "https://tour-service-686574767001.europe-west1.run.app"
      }
    }
  }
}

# Cloud Run - stakeholders-service
resource "google_cloud_run_v2_service" "stakeholders_service" {
  name     = "stakeholders-service"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/stakeholders-service:v2"

      env {
        name  = "DB_HOST"
        value = "34.52.224.148"
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_USER"
        value = "postgres"
      }
      env {
        name  = "DB_NAME"
        value = "stakeholders"
      }
      env {
        name  = "BASE_URL"
        value = "https://stakeholders-service-686574767001.europe-west1.run.app"
      }
      env {
        name = "JWT_SECRET"
        value_source {
          secret_key_ref {
            secret  = "jwt-secret"
            version = "latest"
          }
        }
      }
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = "postgres-password"
            version = "latest"
          }
        }
      }
      env {
        name  = "ALLOWED_ORIGINS"
        value = "https://tourism-app-migration.web.app"
      }
    }
  }
}

# Cloud Run - tour-service
resource "google_cloud_run_v2_service" "tour_service" {
  name     = "tour-service"
  location = "europe-west1"

  template {
    containers {
      image = "europe-west1-docker.pkg.dev/tourism-app-migration/tourism-images/tour-service:v1"

      ports {
        name           = "h2c"
        container_port = 8083
      }

      env {
        name  = "PAYMENT_GRPC_ADDR"
        value = "payment-service-686574767001.europe-west1.run.app:443"
      }
      env {
        name  = "NATS_URL"
        value = "nats://${google_compute_address.nats_static_ip.address}:4222"
      }
      env {
        name  = "GRPC_TLS_ENABLED"
        value = "true"
      }
      env {
        name = "MONGODB_URI"
        value_source {
          secret_key_ref {
            secret  = "mongodb-uri-tours"
            version = "latest"
          }
        }
      }
    }
  }
}
