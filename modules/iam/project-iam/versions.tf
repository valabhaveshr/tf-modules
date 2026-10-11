###############################################################################
# versions.tf - Terraform and provider version constraints for the
# iam/project-iam module.
#
# NOTE: No provider blocks are declared here. The caller (the portal's
# generated root config) configures google / google-beta and, if needed,
# passes aliases in with `providers = { ... }` on the module block.
###############################################################################

terraform {
  # 1.11 is the floor: the allow_privileged_roles guard and the IAM condition
  # checks are cross-variable validations.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.0"
    }
  }
}
