###############################################################################
# versions.tf - Terraform and provider version constraints for the
# compute/instance module.
#
# NOTE: No provider blocks are declared here. The caller (the portal's
# generated root config) configures google / google-beta and, if needed,
# passes aliases in with `providers = { ... }` on the module block.
###############################################################################

terraform {
  # 1.11 is the floor: cross-variable validation (zone vs. subnetwork,
  # metadata vs. startup_script) needs it.
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
