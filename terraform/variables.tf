variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "tourism-app-migration"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "europe-west1"
}

variable "nats_vm_zone" {
  description = "Zone for NATS VM"
  type        = string
  default     = "us-central1-a"
}

variable "nats_vm_ip" {
  description = "Static IP for NATS VM"
  type        = string
  default     = "136.111.103.170"
}
