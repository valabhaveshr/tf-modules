###############################################################################
# outputs.tf - Output contract for the compute/instance module.
#
# NOTE: One module call = one VM, so every output is a single value. With the
# portal's `for_each`, read them as module.<name>["<instance>"].<output>.
###############################################################################

output "id" {
  description = "The VM's resource ID, projects/<project>/zones/<zone>/instances/<name>."
  value       = google_compute_instance.this.id
}

output "instance_id" {
  description = "The VM's numeric server-assigned ID."
  value       = google_compute_instance.this.instance_id
}

output "self_link" {
  description = "The VM's full self link URL."
  value       = google_compute_instance.this.self_link
}

output "name" {
  description = "The VM's name."
  value       = google_compute_instance.this.name
}

output "zone" {
  description = "The zone the VM runs in."
  value       = google_compute_instance.this.zone
}

output "internal_ip" {
  description = "The VM's internal IPv4 address."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "The VM's ephemeral external IPv4 address, or null unless enable_public_access is true."
  value       = try(google_compute_instance.this.network_interface[0].access_config[0].nat_ip, null)
}

output "service_account_email" {
  description = "The email of the service account the VM runs as."
  value       = google_compute_instance.this.service_account[0].email
}
