###############################################################################
# main.tf - Resources for the compute/instance module.
#
# GCP services: Compute Engine (VM instance), Cloud KMS (CMEK boot disk),
# OS Login.
#
# NOTE: One module call = one VM. The portal creates several VMs by calling
# the module with `for_each`, one call per instance.
# NOTE: Private and hardened by default: no external IP unless
# enable_public_access = true; a dedicated service account with the
# cloud-platform scope (access controlled by IAM roles only); Shielded VM;
# OS Login enforced, project SSH keys and the serial console blocked;
# deletion protection on. The boot disk takes CMEK through
# boot_disk_kms_key_self_link; the Compute Engine service agent needs
# roles/cloudkms.cryptoKeyEncrypterDecrypter on the key.
###############################################################################

locals {
  # Metadata the module always sets, overriding anything the caller passes:
  # OS Login for SSH (IAM-controlled, audited), no project-wide SSH keys and no
  # interactive serial console.
  enforced_metadata = {
    "enable-oslogin"         = "TRUE"
    "block-project-ssh-keys" = "TRUE"
    "serial-port-enable"     = "FALSE"
  }

  # Final metadata: caller keys first, so the enforced keys always win.
  metadata = merge(var.metadata, local.enforced_metadata)

  # Whether this is a SPOT VM.
  spot = var.provisioning_model == "SPOT"

  # SPOT VMs and Confidential VMs cannot live-migrate during host maintenance.
  on_host_maintenance = local.spot || var.enable_confidential_compute ? "TERMINATE" : "MIGRATE"
}

# The VM instance.
resource "google_compute_instance" "this" {
  #checkov:skip=CKV_GCP_32:block-project-ssh-keys = TRUE is always set from local.enforced_metadata (callers cannot override it); checkov cannot evaluate the merged map.
  #checkov:skip=CKV_GCP_40:An external IP is attached only when enable_public_access = true; checkov cannot evaluate the dynamic block.
  project                   = var.project_id
  name                      = var.name
  zone                      = var.zone
  hostname                  = var.hostname
  description               = var.description
  machine_type              = var.machine_type
  can_ip_forward            = var.enable_ip_forwarding
  tags                      = var.network_tags
  metadata                  = local.metadata
  metadata_startup_script   = var.startup_script
  deletion_protection       = var.deletion_protection
  allow_stopping_for_update = true
  labels                    = var.labels

  # Boot disk, CMEK-encrypted when a key is given; deleted with the VM.
  boot_disk {
    auto_delete       = true
    kms_key_self_link = var.boot_disk_kms_key_self_link

    initialize_params {
      image  = var.boot_disk_image
      type   = var.boot_disk_type
      size   = var.boot_disk_size_gb
      labels = var.labels
    }
  }

  # Existing disks; their encryption is configured on the disk itself.
  dynamic "attached_disk" {
    for_each = var.attached_disks
    content {
      source      = attached_disk.value.source
      device_name = attached_disk.value.device_name
      mode        = attached_disk.value.mode == null ? "READ_WRITE" : attached_disk.value.mode
    }
  }

  # Internal IP in the given subnet; an ephemeral external IP only with
  # enable_public_access.
  network_interface {
    subnetwork = var.subnetwork
    network_ip = var.network_ip

    dynamic "access_config" {
      for_each = var.enable_public_access ? [1] : []
      content {}
    }
  }

  # Dedicated service account; the broad scope is intentional, IAM roles on
  # the service account are what actually limit access.
  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = var.enable_vtpm
    enable_integrity_monitoring = var.enable_integrity_monitoring
  }

  dynamic "confidential_instance_config" {
    for_each = var.enable_confidential_compute ? [1] : []
    content {
      enable_confidential_compute = true
    }
  }

  scheduling {
    provisioning_model          = var.provisioning_model
    preemptible                 = local.spot
    automatic_restart           = !local.spot
    on_host_maintenance         = local.on_host_maintenance
    instance_termination_action = local.spot ? var.spot_termination_action : null
  }
}
