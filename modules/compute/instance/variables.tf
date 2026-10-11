###############################################################################
# variables.tf - Input contract for the compute/instance module.
#
# GCP services: Compute Engine (VM instances, persistent disks, Shielded VM,
# Confidential VM), Cloud KMS (CMEK), OS Login.
#
# NOTE: One module call creates exactly one VM. Every input is a flat,
# per-instance value so the portal can render it as a native form field and
# call the module once per instance with `for_each`.
# NOTE: The portal's variables.tf parser reads `default`, `description`,
# `sensitive`, `nullable` and `error_message` without an evaluation context,
# so they must stay plain literals (no functions, no interpolation). A
# required input is one with no default and `nullable = false`.
# NOTE: Variables are declared in the same order as metadata.yaml lists them.
###############################################################################

#------------------------------------------------------------------------------
# Basics
#------------------------------------------------------------------------------

variable "project_id" {
  description = "ID of the GCP project the VM is created in. 6-30 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "name" {
  description = "Name of the VM, unique within the project and zone. 1-63 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen (RFC 1035)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.name))
    error_message = "name must be RFC 1035 compliant: 1-63 lowercase letters, digits or hyphens, starting with a letter and not ending with a hyphen."
  }
}

variable "zone" {
  description = "Zone the VM runs in, for example us-central1-a. It must be in the same region as the subnetwork."
  type        = string
  nullable    = false

  # NOTE: Cross-variable validation (Terraform >= 1.9): the zone must belong to
  # the subnetwork's region. Only this direction is checked, because a reverse
  # reference from subnetwork would create a validation cycle.
  validation {
    condition = (
      can(regex("^[a-z]+-[a-z]+[0-9]+-[a-z]$", var.zone))
      && startswith(var.zone, "${try(regex("/regions/([a-z0-9-]+)/", var.subnetwork)[0], "")}-")
    )
    error_message = "zone must be a zone such as \"us-central1-a\" in the subnetwork's region."
  }
}

variable "machine_type" {
  description = "Machine type that sets the VM's vCPUs and memory, for example e2-standard-2, n2d-standard-4 or custom-4-8192 (custom-<vCPUs>-<memory MB>)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^([a-z][a-z0-9]*-[a-z0-9-]+|custom-[0-9]+-[0-9]+(-ext)?)$", var.machine_type))
    error_message = "machine_type must be a machine type such as \"e2-standard-2\" or \"custom-4-8192\"."
  }
}

variable "description" {
  description = "Free-text description of the VM, shown in the Cloud Console. Leave empty for none."
  type        = string
  default     = null
}

variable "labels" {
  description = "Labels applied to the VM and its boot disk, as key = value pairs. Keys: lowercase letters, digits, _ and -, starting with a letter (max 63). Values: lowercase letters, digits, _ and - (max 63)."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for k, v in var.labels :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", k)) && can(regex("^[a-z0-9_-]{0,63}$", v))
    ])
    error_message = "Label keys must match ^[a-z][a-z0-9_-]{0,62}$ and values must match ^[a-z0-9_-]{0,63}$."
  }
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------

variable "subnetwork" {
  description = "Subnet the VM's network interface is attached to, as an ID (projects/<project>/regions/<region>/subnetworks/<name>) or full self link. A Shared VPC subnet in a host project works too."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(https://www\\.googleapis\\.com/compute/v1/)?projects/[a-z0-9-]+/regions/[a-z]+-[a-z]+[0-9]+/subnetworks/[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.subnetwork))
    error_message = "subnetwork must be a subnet ID (projects/<p>/regions/<r>/subnetworks/<s>) or self link."
  }
}

variable "network_ip" {
  description = "Static internal IPv4 address for the VM, for example 10.10.0.5. It must be a free address inside the subnet's range. Leave empty for an ephemeral address."
  type        = string
  default     = null

  validation {
    condition     = var.network_ip == null ? true : can(cidrnetmask("${var.network_ip}/32"))
    error_message = "network_ip must be a single IPv4 address such as \"10.10.0.5\"."
  }
}

variable "network_tags" {
  description = "Network tags used by firewall rules and routes to target this VM, for example [\"web\", \"allow-health-checks\"]. Each tag: 1-63 lowercase letters, digits or hyphens, starting with a letter."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for t in var.network_tags : can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", t))])
    error_message = "network_tags must be RFC 1035 compliant: 1-63 lowercase letters, digits or hyphens, starting with a letter."
  }

  validation {
    condition     = length(distinct(var.network_tags)) == length(var.network_tags)
    error_message = "network_tags must not contain duplicates."
  }
}

variable "enable_public_access" {
  description = "Attach an ephemeral external (public) IPv4 address to the VM. Off by default: VMs are private and should reach the internet through Cloud NAT."
  type        = bool
  default     = false
  nullable    = false
}

variable "hostname" {
  description = "Custom fully qualified hostname for the VM, for example app01.internal.example.com. Leave empty to use the GCP default (<name>.<zone>.c.<project>.internal)."
  type        = string
  default     = null

  validation {
    condition     = var.hostname == null ? true : can(regex("^([a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.hostname))
    error_message = "hostname must be a fully qualified DNS name such as \"app01.internal.example.com\"."
  }
}

variable "enable_ip_forwarding" {
  description = "Allow the VM to send and receive packets for IP addresses other than its own (needed for NAT gateways, routers and network appliances). Off by default."
  type        = bool
  default     = false
  nullable    = false
}

#------------------------------------------------------------------------------
# Boot disk
#------------------------------------------------------------------------------

variable "boot_disk_image" {
  description = "Image the boot disk is created from: <project>/<family-or-image> such as debian-cloud/debian-12, projects/<p>/global/images/family/<family>, or a full image self link."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9:/._-]*/[a-zA-Z0-9._-]+$", var.boot_disk_image))
    error_message = "boot_disk_image must be an image reference such as \"debian-cloud/debian-12\", projects/<p>/global/images/family/<f> or an image self link."
  }
}

variable "boot_disk_type" {
  description = "Boot disk type. One of: pd-balanced (default), pd-standard, pd-ssd, pd-extreme, hyperdisk-balanced, hyperdisk-throughput, hyperdisk-extreme."
  type        = string
  default     = "pd-balanced"
  nullable    = false

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme", "hyperdisk-balanced", "hyperdisk-throughput", "hyperdisk-extreme"], var.boot_disk_type)
    error_message = "boot_disk_type must be one of pd-standard, pd-balanced, pd-ssd, pd-extreme, hyperdisk-balanced, hyperdisk-throughput or hyperdisk-extreme."
  }
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB, a whole number of at least 10. Leave empty to use the image's own size."
  type        = number
  default     = null

  validation {
    condition     = var.boot_disk_size_gb == null ? true : (var.boot_disk_size_gb >= 10 && floor(var.boot_disk_size_gb) == var.boot_disk_size_gb)
    error_message = "boot_disk_size_gb must be a whole number of at least 10."
  }
}

variable "boot_disk_kms_key_self_link" {
  description = "Cloud KMS key that encrypts the boot disk (CMEK), as projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>. Leave empty for Google-managed encryption. The Compute Engine service agent needs roles/cloudkms.cryptoKeyEncrypterDecrypter on the key."
  type        = string
  default     = null

  validation {
    condition     = var.boot_disk_kms_key_self_link == null ? true : can(regex("^projects/[a-z0-9-]+/locations/[a-z0-9-]+/keyRings/[a-zA-Z0-9_-]{1,63}/cryptoKeys/[a-zA-Z0-9_-]{1,63}$", var.boot_disk_kms_key_self_link))
    error_message = "boot_disk_kms_key_self_link must be a crypto key ID: projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>."
  }
}

#------------------------------------------------------------------------------
# Security
#------------------------------------------------------------------------------

variable "service_account_email" {
  description = "Email of the dedicated service account the VM runs as, <name>@<project>.iam.gserviceaccount.com. The Compute Engine default service account is rejected. The scope is always cloud-platform, so access is controlled by IAM roles only."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a dedicated service account (<sa>@<project>.iam.gserviceaccount.com); the Compute Engine default service account is not allowed."
  }
}

variable "deletion_protection" {
  description = "Prevent the VM from being deleted (by Terraform or in the Console) until this is turned off. On by default."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_secure_boot" {
  description = "Shielded VM Secure Boot: only boot software signed by trusted keys. On by default; turn off only for images with unsigned drivers or kernels."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_vtpm" {
  description = "Shielded VM virtual Trusted Platform Module (vTPM), used for measured boot and integrity monitoring. On by default."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_integrity_monitoring" {
  description = "Shielded VM integrity monitoring: compare each boot against a known-good baseline and report deviations. On by default."
  type        = bool
  default     = true
  nullable    = false
}

variable "enable_confidential_compute" {
  description = "Run the VM as a Confidential VM with encrypted memory. Needs a supported machine family (for example n2d, c2d or c3) and disables live migration. Off by default."
  type        = bool
  default     = false
  nullable    = false
}

#------------------------------------------------------------------------------
# Scheduling
#------------------------------------------------------------------------------

variable "provisioning_model" {
  description = "STANDARD (default) for a regular VM, or SPOT for a much cheaper VM that Google can stop or delete at any time to reclaim capacity."
  type        = string
  default     = "STANDARD"
  nullable    = false

  validation {
    condition     = contains(["STANDARD", "SPOT"], var.provisioning_model)
    error_message = "provisioning_model must be STANDARD or SPOT."
  }
}

variable "spot_termination_action" {
  description = "What happens to a SPOT VM when Google reclaims it: STOP (default, the VM and its disks are kept) or DELETE. Ignored for STANDARD VMs."
  type        = string
  default     = "STOP"
  nullable    = false

  validation {
    condition     = contains(["STOP", "DELETE"], var.spot_termination_action)
    error_message = "spot_termination_action must be STOP or DELETE."
  }
}

#------------------------------------------------------------------------------
# Advanced
#------------------------------------------------------------------------------

variable "startup_script" {
  description = "Script run as root on every boot (stored as the startup-script metadata value), for example a bash script starting with #!/bin/bash. Leave empty for none. Do not put secrets here; read them from Secret Manager instead."
  type        = string
  default     = null
}

variable "metadata" {
  description = "Extra instance metadata as key = value pairs. The keys enable-oslogin, block-project-ssh-keys, serial-port-enable, ssh-keys and sshKeys are reserved (the module enforces OS Login and blocks SSH keys and the serial console); use startup_script instead of a startup-script key."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(setintersection(keys(var.metadata), ["enable-oslogin", "block-project-ssh-keys", "serial-port-enable", "ssh-keys", "sshKeys"])) == 0
    error_message = "metadata must not set enable-oslogin, block-project-ssh-keys, serial-port-enable, ssh-keys or sshKeys; the module enforces OS Login and blocks SSH keys and the serial port."
  }

  # NOTE: Cross-variable validation. The provider rejects metadata_startup_script
  # together with a startup-script metadata key.
  validation {
    condition     = var.startup_script == null ? true : !contains(keys(var.metadata), "startup-script")
    error_message = "Set the startup script either through startup_script or through a metadata startup-script key, not both."
  }
}

# Schema: existing persistent disks to attach (create them with compute/disk;
# their encryption is configured on the disk itself).
#   source      -> disk ID or self link: projects/<p>/zones/<z>/disks/<d> or projects/<p>/regions/<r>/disks/<d>
#   device_name -> name the disk appears under in the guest (/dev/disk/by-id/google-<device_name>), RFC 1035
#   mode        -> READ_WRITE (when null) or READ_ONLY
# NOTE: `mode` is optional(string) without a default argument on purpose: the
# portal parses types with hcl's TypeConstraint, which rejects
# optional(type, default). main.tf applies the READ_WRITE default instead.
variable "attached_disks" {
  description = "Existing persistent disks to attach to the VM, as a list of objects with source (disk ID or self link), device_name (RFC 1035) and optional mode (READ_WRITE by default, or READ_ONLY). Leave empty for none."
  type = list(object({
    source      = string
    device_name = string
    mode        = optional(string)
  }))
  default  = []
  nullable = false

  validation {
    condition     = length(distinct([for d in var.attached_disks : d.device_name])) == length(var.attached_disks)
    error_message = "attached_disks device_name values must be unique."
  }

  validation {
    condition = alltrue([
      for d in var.attached_disks :
      can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", d.device_name))
      && (d.mode == null ? true : contains(["READ_WRITE", "READ_ONLY"], d.mode))
      && can(regex("^(https://www\\.googleapis\\.com/compute/v1/)?projects/[a-z0-9-]+/(zones/[a-z]+-[a-z]+[0-9]+-[a-z]|regions/[a-z]+-[a-z]+[0-9]+)/disks/[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", d.source))
    ])
    error_message = "attached_disks need a disk ID or self link as source, an RFC 1035 device_name and mode READ_WRITE or READ_ONLY (or null)."
  }
}
