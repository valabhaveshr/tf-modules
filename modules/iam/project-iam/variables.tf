###############################################################################
# variables.tf - Input contract for the iam/project-iam module.
#
# GCP services: IAM (project-level role grants).
#
# NOTE: One module call grants exactly one role to one principal. Every input
# is a flat, per-grant value so the portal can render it as a native form
# field and call the module once per grant with `for_each`.
# NOTE: The portal's variables.tf parser reads `default`, `description`,
# `sensitive`, `nullable` and `error_message` without an evaluation context,
# so they must stay plain literals (no functions, no interpolation). A
# required input is one with no default and `nullable = false`.
# NOTE: IAM grants cannot carry labels, so this module has no `labels` input.
# NOTE: Variables are declared in the same order as metadata.yaml lists them.
###############################################################################

#------------------------------------------------------------------------------
# Basics
#------------------------------------------------------------------------------

variable "project_id" {
  description = "ID of the GCP project the role is granted on. 6-30 characters: lowercase letters, digits and hyphens, starting with a letter and not ending with a hyphen."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters of lowercase letters, digits and hyphens, start with a letter and not end with a hyphen."
  }
}

variable "member" {
  description = "Principal that receives the role, with its type prefix: user:alice@example.com, group:devs@example.com, serviceAccount:<sa>@<project>.iam.gserviceaccount.com, domain:example.com, or a principal:// / principalSet:// workload identity. allUsers and allAuthenticatedUsers are rejected."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^((user|group|serviceAccount|domain|deleted:user|deleted:group|deleted:serviceAccount):[^\\s]+|principal(Set)?://[^\\s]+)$", var.member))
    error_message = "member must be a user:, group:, serviceAccount:, domain: or principal(Set):// principal; allUsers and allAuthenticatedUsers are not allowed."
  }
}

variable "role" {
  description = "Role to grant: a predefined role such as roles/compute.viewer, or a custom role as projects/<project>/roles/<id> or organizations/<org-id>/roles/<id>. roles/owner and roles/editor are rejected unless allow_privileged_roles is true."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(roles/[a-zA-Z0-9_.]+|projects/[a-z0-9-]+/roles/[a-zA-Z0-9_.]+|organizations/[0-9]+/roles/[a-zA-Z0-9_.]+)$", var.role))
    error_message = "role must be a predefined (roles/...) or custom (projects/<p>/roles/... or organizations/<id>/roles/...) role name."
  }

  # NOTE: Cross-variable validation (Terraform >= 1.9): least-privilege guard.
  validation {
    condition     = var.allow_privileged_roles || !contains(["roles/owner", "roles/editor"], var.role)
    error_message = "roles/owner and roles/editor violate least privilege; grant a narrower role or set allow_privileged_roles = true."
  }
}

#------------------------------------------------------------------------------
# IAM condition (optional)
#------------------------------------------------------------------------------

variable "condition_title" {
  description = "Title of an optional IAM Condition that limits when the grant applies, for example temporary-access-until-2026-12-31 (max 100 characters). Leave empty for an unconditional grant; set it together with condition_expression."
  type        = string
  default     = null

  validation {
    condition     = var.condition_title == null ? true : (length(trimspace(var.condition_title)) > 0 && length(var.condition_title) <= 100)
    error_message = "condition_title must be 1-100 characters and not blank."
  }
}

variable "condition_expression" {
  description = "CEL expression of the IAM Condition, for example request.time < timestamp(\"2026-12-31T00:00:00Z\"). Required when condition_title is set; leave empty otherwise."
  type        = string
  default     = null

  # NOTE: Cross-variable validation: title and expression go together.
  validation {
    condition     = (var.condition_title == null) == (var.condition_expression == null)
    error_message = "condition_title and condition_expression must be set together (or both left empty)."
  }

  validation {
    condition     = var.condition_expression == null ? true : length(trimspace(var.condition_expression)) > 0
    error_message = "condition_expression must not be blank."
  }
}

variable "condition_description" {
  description = "Optional free-text description of the IAM Condition, for example Temporary access for the Q4 migration. Only used when condition_title is set."
  type        = string
  default     = null

  # NOTE: Cross-variable validation: a description without a condition would
  # be silently dropped, so reject it.
  validation {
    condition     = var.condition_description == null ? true : var.condition_title != null
    error_message = "condition_description needs condition_title and condition_expression to be set."
  }
}

#------------------------------------------------------------------------------
# Least-privilege guard
#------------------------------------------------------------------------------

variable "allow_privileged_roles" {
  description = "Allow granting the basic roles/owner or roles/editor roles. Leave false unless a break-glass grant is explicitly approved."
  type        = bool
  default     = false
  nullable    = false
}
