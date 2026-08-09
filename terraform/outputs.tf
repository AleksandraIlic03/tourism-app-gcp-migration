output "api_gateway_url" {
  description = "URL api-gateway servisa"
  value       = google_cloud_run_v2_service.api_gateway.uri
}

output "stakeholders_service_url" {
  description = "URL stakeholders servisa"
  value       = google_cloud_run_v2_service.stakeholders_service.uri
}

output "blog_service_url" {
  description = "URL blog servisa"
  value       = google_cloud_run_v2_service.blog_service.uri
}

output "tour_service_url" {
  description = "URL tour servisa"
  value       = google_cloud_run_v2_service.tour_service.uri
}

output "payment_service_url" {
  description = "URL payment servisa"
  value       = google_cloud_run_v2_service.payment_service.uri
}

output "follower_service_url" {
  description = "URL follower servisa"
  value       = google_cloud_run_v2_service.follower_service.uri
}

output "nats_vm_ip" {
  description = "Javna IP adresa NATS VM-a"
  value       = var.nats_vm_ip
}

output "cloud_sql_instance" {
  description = "Cloud SQL instanca"
  value       = google_sql_database_instance.stakeholders_db.connection_name
}