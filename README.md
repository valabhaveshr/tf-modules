# tf-modules

Terraform modules for GCP, written to be consumed by the self-service Terraform portal (`tf-automation`). Each module is a flattened, "portal-friendly" rewrite of a module from the main GCP registry: **one module call creates one resource instance**, and every input is a simple, per-instance value that the portal can render as a native form field.

## Catalog

| Module | Path | Creates | Form label field |
|---|---|---|---|
| Compute Instance | `modules/compute/instance` | One hardened Compute Engine VM | `name` |
| Project IAM Grant | `modules/iam/project-iam` | One additive project IAM role grant (`google_project_iam_member`) | `member` |

## How the portal consumes a module

1. **Discovery.** The portal lists the repo's tags. Only modules with at least one tag of the form `<module-path>/vX.Y.Z` appear in the catalog (see [Tagging and releasing](#tagging-and-releasing)).
2. **Schema.** For the chosen tag it parses the module's `variables.tf` (name, type, default, description, `sensitive`, `nullable`, validation messages) and its `metadata.yaml` (display name, icon, form groups, examples).
3. **Form.** One form section per `group`, in order of first use; inputs marked `advanced: true` are collapsed. A variable's `description` is the hover "i" text and its `example` the hover "e" text. A variable with no `default` and `nullable = false` is required.
4. **Code generation.** For each selected module the portal writes one module block with `for_each` over a map of instances, passing every variable through:

   ```hcl
   module "compute_instance" {
     source       = "git::https://github.com/<org>/<repo>.git//modules/compute/instance?ref=modules/compute/instance/v1.0.0"
     for_each     = var.compute_instance_instances # map: instance key -> object of ALL the module's variables
     name         = each.value.name
     machine_type = each.value.machine_type
     # ...one line per variable in variables.tf
   }
   ```

   The values live in a per-module `<module>.auto.tfvars`, and the root `variables.tf` declares `<module>_instances` as `map(object({...}))` with one plain-typed field per module variable. Unset optional values are written as their default (or `null`).

## Module conventions

Every module lives in `modules/<category>/<module>/` and contains:

| File | Contents |
|---|---|
| `versions.tf` | `required_version` and `required_providers` only. **No `provider` block**: the generated root config configures providers. |
| `variables.tf` | The input contract, declared in the same order as `metadata.yaml` lists the variables. |
| `main.tf` | Locals (if any) and the resource. |
| `outputs.tf` | Single-value outputs for the one resource (id, self link, name, ...). |
| `metadata.yaml` | Portal metadata (contract below). |
| `README.md` | Description, usage example, inputs table, outputs. |

### Input design rules

- **One call = one resource instance.** No `<x>_config` list-of-objects inputs; multiple instances are the portal's `for_each`.
- **Flat, self-explanatory inputs** (`name`, `zone`, `machine_type`, `boot_disk_size_gb`, `enable_secure_boot`, ...).
- **Prefer types the form renders natively:** `string`, `number`, `bool`, `list(string)`, `map(string)`. `object(...)` / `list(object(...))` fall back to a raw-JSON text box; use them only where flattening would lose real capability (e.g. a VM's `attached_disks`).
- **Inside an object type, use `optional(type)` without a default argument.** The portal parses types with HCL's `TypeConstraint`, which rejects `optional(type, default)` and would degrade the whole variable to `any`. Apply the default in `main.tf` instead (`x == null ? "DEFAULT" : x`).
- **Required inputs** have no `default` and set `nullable = false`. **Optional inputs** have a sensible default; use `default = null` for "not set" strings and numbers. Optional `bool` / `list` / `map` inputs set `nullable = false` so an explicit `null` falls back to the default.
- **Literal attributes only** for `description`, `default`, `sensitive`, `nullable` and `error_message` (no functions, references or interpolation): the portal reads them without an evaluation context.
- **Descriptions** are user-facing, 1-2 sentences, and state the format and allowed values.
- **Secrets** are `sensitive = true`.
- **Validation:** port the source module's validation to the flat inputs. Cross-variable validation needs Terraform >= 1.9 (floor here is 1.11) and only works in one direction (a reverse reference is a cycle). `||` / `&&` do not short-circuit on 1.11, so guard nullable inputs with `x == null ? true : ...`.
- **Common inputs:** `project_id` (required, validated) on every module; `labels` (`map(string)`, default `{}`, GCP label format validated) on every module whose resource can be labelled.
- **Security posture:** private by default, least privilege, security-positive settings default on (Shielded VM, deletion protection, OS Login), public principals rejected in IAM, privileged roles behind an explicit opt-in.

### `metadata.yaml` contract

```yaml
name: instance                    # MUST equal the module's leaf folder name
display_name: "Compute Instance"
category: "Compute"               # "Compute" / "IAM" / ...
cloud: "gcp"
icon: "server"                    # key into the portal's icon set (VM: server, IAM: key)
description: "One-sentence summary shown in the module picker."
instance_label_field: "name"      # the variable whose value labels each instance in the UI
variables:                        # one entry for EVERY variable in variables.tf, in form order
  project_id:
    example: "acme-prod-app-01"   # required; shown verbatim. list/map/object: an HCL literal such as '["web"]'
    group: "Basics"               # required; form section heading
  enable_ip_forwarding:
    example: "false"
    group: "Networking"
    advanced: true                # optional; collapsed under "Advanced"
```

Every variable in `variables.tf` must have an entry with an `example` and a `group`, and there must be no entries for variables that don't exist. Order required and most common fields first.

## Tagging and releasing

Modules are versioned independently by **path-scoped git tags** in this monorepo:

```
modules/<category>/<module>/vMAJOR.MINOR.PATCH     e.g. modules/compute/instance/v1.0.0
```

(The portal also accepts the unprefixed form `<category>/<module>/vX.Y.Z`; use the prefixed form so the tag equals the `?ref=` in generated sources.) Pre-release suffixes (`-rc1`) are ignored by the catalog.

- **MAJOR**: a breaking input/output change (removing or renaming a variable, making an optional input required, changing a type, tightening validation that existing values could fail, removing an output).
- **MINOR**: a backward-compatible feature (a new optional input with a default, a new output).
- **PATCH**: a fix with no contract change.

Each generated instance pins the exact tag it was created with, so existing records keep working until they are deliberately upgraded.

To release (run by a human; nothing here is tagged automatically):

```sh
terraform fmt -check -recursive
terraform -chdir=modules/compute/instance init -backend=false
terraform -chdir=modules/compute/instance validate
git tag modules/compute/instance/v1.0.0
git push origin modules/compute/instance/v1.0.0
```

Pushing the tag fires the portal's webhook (push + tag-create); its periodic reconciliation and the admin-only manual refresh pick it up as well.

## Requirements

- Terraform `>= 1.11.0, < 2.0.0`
- Providers `hashicorp/google` and `hashicorp/google-beta` `~> 8.0` (configured by the caller)
