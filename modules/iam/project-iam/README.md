# iam/project-iam

One IAM role grant to one principal on a project per module call, using the additive `google_project_iam_member`. This is a flattened, "portal-friendly" rewrite of the registry's `iam/project-iam` module: instead of a `project_iam_config` list of principals with role lists, every input is a scalar, and multiple grants are created by calling the module with `for_each`.

Security posture:

- Additive only (`google_project_iam_member`); never authoritative `_binding` / `_policy`, so grants managed elsewhere are untouched.
- `allUsers` and `allAuthenticatedUsers` are rejected; `member` must carry a principal type prefix.
- `roles/owner` and `roles/editor` are rejected unless `allow_privileged_roles = true` (break-glass opt-in).
- Optional IAM Condition (for example time-bound access); title and expression must be set together.

## Usage

The portal generates this shape (one call per grant, every input set per grant):

```hcl
module "project_iam" {
  source   = "git::https://github.com/<org>/<repo>.git//modules/iam/project-iam?ref=modules/iam/project-iam/v1.0.0"
  for_each = var.project_iam_instances

  project_id             = each.value.project_id
  member                 = each.value.member
  role                   = each.value.role
  condition_title        = each.value.condition_title
  condition_expression   = each.value.condition_expression
  condition_description  = each.value.condition_description
  allow_privileged_roles = each.value.allow_privileged_roles
}
```

A hand-written single call, time-bound:

```hcl
module "app_sa_log_writer" {
  source = "git::https://github.com/<org>/<repo>.git//modules/iam/project-iam?ref=modules/iam/project-iam/v1.0.0"

  project_id = "acme-prod-app-01"
  member     = "serviceAccount:sa-app-vm@acme-prod-app-01.iam.gserviceaccount.com"
  role       = "roles/logging.logWriter"

  condition_title      = "temporary-access-until-2026-12-31"
  condition_expression = "request.time < timestamp(\"2026-12-31T00:00:00Z\")"
}
```

## Inputs

Listed in form order (see `metadata.yaml` for the form group, example and "advanced" flag of each input).

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | `string` | required | Project the role is granted on (6-30 chars, lowercase letters, digits, hyphens). |
| `member` | `string` | required | `user:`, `group:`, `serviceAccount:`, `domain:` or `principal://` / `principalSet://` principal; public principals are rejected. |
| `role` | `string` | required | `roles/...`, `projects/<p>/roles/...` or `organizations/<id>/roles/...`. |
| `condition_title` | `string` | `null` | IAM Condition title (1-100 chars); null = unconditional grant. |
| `condition_expression` | `string` | `null` | IAM Condition CEL expression; required when `condition_title` is set. |
| `condition_description` | `string` | `null` | IAM Condition description; needs `condition_title`. |
| `allow_privileged_roles` | `bool` | `false` | Allow `roles/owner` / `roles/editor`. |

## Outputs

| Name | Description |
|---|---|
| `id` | Grant resource ID (built by the provider from project, role, member and condition title). |
| `etag` | Etag of the project IAM policy after the grant. |
| `project` | Project the role is granted on. |
| `role` | Granted role. |
| `member` | Principal that received the role. |
| `condition_title` | Condition title, or `null` for an unconditional grant. |

With the portal's `for_each`, read an output as `module.project_iam["<instance>"].etag`.

## Requirements

| Name | Version |
|---|---|
| terraform | `>= 1.11.0, < 2.0.0` |
| google | `~> 8.0` |
| google-beta | `~> 8.0` (declared for parity with the registry; unused) |

## Differences from the registry's `iam/project-iam`

- One (member, role) grant per call instead of `project_iam_config` (list of principals, each with a list of roles). The logical `name` key is dropped; the portal's instance key replaces it.
- The `condition` object is flattened into `condition_title`, `condition_expression` and `condition_description`.
- `required_labels` / `additional_labels` and the `labels` output are dropped: IAM grants cannot be labelled.
- Outputs are single values instead of the `grants` / `roles_by_name` maps.
