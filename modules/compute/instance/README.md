# compute/instance

One hardened Compute Engine VM per module call. This is a flattened, "portal-friendly" rewrite of the registry's `compute/instance` module: instead of a `instance_config` list of objects, every setting is its own scalar input, and multiple VMs are created by calling the module with `for_each`.

Private and hardened by default:

- No external IP unless `enable_public_access = true` (use Cloud NAT for egress).
- A dedicated service account is required; the Compute Engine default service account is rejected. The scope is always `cloud-platform`, so IAM roles are the only access control.
- OS Login is enforced through module-owned metadata (`enable-oslogin = TRUE`, `block-project-ssh-keys = TRUE`, `serial-port-enable = FALSE`). Callers cannot override these keys, and `ssh-keys` / `sshKeys` are rejected.
- Shielded VM (Secure Boot, vTPM, integrity monitoring) on by default.
- `deletion_protection` on by default.
- Optional CMEK for the boot disk via `boot_disk_kms_key_self_link`. The Compute Engine service agent (`service-<project-number>@compute-system.iam.gserviceaccount.com`) needs `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the key.
- Optional SPOT provisioning (`provisioning_model = "SPOT"`) with `STOP` or `DELETE` on preemption.

SSH access is granted per user with `roles/compute.osLogin` (or `roles/compute.osAdminLogin`), for example through `iam/project-iam`.

## Usage

The portal generates this shape (one call per instance, every input set per instance):

```hcl
module "compute_instance" {
  source   = "git::https://github.com/<org>/<repo>.git//modules/compute/instance?ref=modules/compute/instance/v1.0.0"
  for_each = var.compute_instance_instances

  project_id                  = each.value.project_id
  name                        = each.value.name
  zone                        = each.value.zone
  machine_type                = each.value.machine_type
  description                 = each.value.description
  labels                      = each.value.labels
  subnetwork                  = each.value.subnetwork
  network_ip                  = each.value.network_ip
  network_tags                = each.value.network_tags
  enable_public_access        = each.value.enable_public_access
  hostname                    = each.value.hostname
  enable_ip_forwarding        = each.value.enable_ip_forwarding
  boot_disk_image             = each.value.boot_disk_image
  boot_disk_type              = each.value.boot_disk_type
  boot_disk_size_gb           = each.value.boot_disk_size_gb
  boot_disk_kms_key_self_link = each.value.boot_disk_kms_key_self_link
  service_account_email       = each.value.service_account_email
  deletion_protection         = each.value.deletion_protection
  enable_secure_boot          = each.value.enable_secure_boot
  enable_vtpm                 = each.value.enable_vtpm
  enable_integrity_monitoring = each.value.enable_integrity_monitoring
  enable_confidential_compute = each.value.enable_confidential_compute
  provisioning_model          = each.value.provisioning_model
  spot_termination_action     = each.value.spot_termination_action
  startup_script              = each.value.startup_script
  metadata                    = each.value.metadata
  attached_disks              = each.value.attached_disks
}
```

A hand-written single call only needs the required inputs:

```hcl
module "vm_app_01" {
  source = "git::https://github.com/<org>/<repo>.git//modules/compute/instance?ref=modules/compute/instance/v1.0.0"

  project_id            = "acme-prod-app-01"
  name                  = "vm-app-prod-01"
  zone                  = "us-central1-a"
  machine_type          = "e2-standard-2"
  subnetwork            = "projects/acme-prod-net-01/regions/us-central1/subnetworks/snet-app"
  boot_disk_image       = "debian-cloud/debian-12"
  service_account_email = "sa-app-vm@acme-prod-app-01.iam.gserviceaccount.com"

  boot_disk_size_gb = 50
  network_tags      = ["web", "allow-health-checks"]
  labels            = { environment = "prod", team = "platform" }
}
```

## Inputs

Listed in form order (see `metadata.yaml` for the form group, example and "advanced" flag of each input).

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | required | Project the VM is created in (6-30 chars, lowercase letters, digits, hyphens). |
| `name` | `string` | required | VM name, RFC 1035 (1-63 chars). |
| `zone` | `string` | required | Zone, e.g. `us-central1-a`; must be in the subnetwork's region. |
| `machine_type` | `string` | required | e.g. `e2-standard-2`, `n2d-standard-4`, `custom-4-8192`. |
| `description` | `string` | `null` | Free-text VM description. |
| `labels` | `map(string)` | `{}` | Labels on the VM and boot disk (GCP label key/value format). |
| `subnetwork` | `string` | required | Subnet ID (`projects/<p>/regions/<r>/subnetworks/<s>`) or self link; Shared VPC subnets work. |
| `network_ip` | `string` | `null` | Static internal IPv4 address; null = ephemeral. |
| `network_tags` | `list(string)` | `[]` | Firewall/route target tags, RFC 1035, unique. |
| `enable_public_access` | `bool` | `false` | Attach an ephemeral external IPv4 address. |
| `hostname` | `string` | `null` | Custom FQDN hostname; null = GCP default. |
| `enable_ip_forwarding` | `bool` | `false` | Allow the VM to route traffic for other addresses. |
| `boot_disk_image` | `string` | required | e.g. `debian-cloud/debian-12`, an image family path or an image self link. |
| `boot_disk_type` | `string` | `"pd-balanced"` | `pd-standard`, `pd-balanced`, `pd-ssd`, `pd-extreme`, `hyperdisk-balanced`, `hyperdisk-throughput`, `hyperdisk-extreme`. |
| `boot_disk_size_gb` | `number` | `null` | Whole number >= 10; null = image size. |
| `boot_disk_kms_key_self_link` | `string` | `null` | CMEK key `projects/<p>/locations/<l>/keyRings/<r>/cryptoKeys/<k>`; null = Google-managed. |
| `service_account_email` | `string` | required | Dedicated `<sa>@<project>.iam.gserviceaccount.com`; the default compute SA is rejected. |
| `deletion_protection` | `bool` | `true` | Block deletion of the VM. |
| `enable_secure_boot` | `bool` | `true` | Shielded VM Secure Boot. |
| `enable_vtpm` | `bool` | `true` | Shielded VM vTPM. |
| `enable_integrity_monitoring` | `bool` | `true` | Shielded VM integrity monitoring. |
| `enable_confidential_compute` | `bool` | `false` | Confidential VM (n2d / c2d / c3 etc.); disables live migration. |
| `provisioning_model` | `string` | `"STANDARD"` | `STANDARD` or `SPOT`. |
| `spot_termination_action` | `string` | `"STOP"` | `STOP` or `DELETE`; SPOT only. |
| `startup_script` | `string` | `null` | Startup script content; must not be combined with a `startup-script` metadata key. |
| `metadata` | `map(string)` | `{}` | Extra metadata; `enable-oslogin`, `block-project-ssh-keys`, `serial-port-enable`, `ssh-keys`, `sshKeys` are reserved. |
| `attached_disks` | `list(object({ source = string, device_name = string, mode = optional(string) }))` | `[]` | Existing disks to attach; `mode` is `READ_WRITE` (when null) or `READ_ONLY`. |

## Outputs

| Name | Description |
|---|---|
| `id` | Resource ID, `projects/<p>/zones/<z>/instances/<name>`. |
| `instance_id` | Numeric server-assigned ID. |
| `self_link` | Full self link URL. |
| `name` | VM name. |
| `zone` | Zone the VM runs in. |
| `internal_ip` | Internal IPv4 address. |
| `external_ip` | Ephemeral external IPv4 address, or `null` unless `enable_public_access`. |
| `service_account_email` | Service account the VM runs as. |

With the portal's `for_each`, read an output as `module.compute_instance["<instance>"].internal_ip`.

## Requirements

| Name | Version |
|---|---|
| terraform | `>= 1.11.0, < 2.0.0` |
| google | `~> 8.0` |
| google-beta | `~> 8.0` (declared for parity with the registry; unused) |

## Differences from the registry's `compute/instance`

- One VM per call instead of `instance_config` (list of objects). Nested `boot_disk` and `shielded_vm` objects are flattened into `boot_disk_*` and `enable_*` inputs.
- `required_labels` / `additional_labels` are replaced by a single optional `labels` map (same key/value validation, no mandatory keys).
- Outputs are single values instead of maps keyed by instance name; the `labels` output is dropped.
