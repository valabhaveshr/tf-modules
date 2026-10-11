###############################################################################
# main.tf - Resources for the iam/project-iam module.
#
# GCP services: IAM (project IAM policy).
#
# NOTE: One module call = one (principal, role) grant. The portal creates
# several grants by calling the module with `for_each`, one call per grant.
# NOTE: Only the additive google_project_iam_member is used. Authoritative
# resources (google_project_iam_binding / _policy) silently remove grants
# made by other tools and can lock administrators out of a project.
###############################################################################

# Additive project role grant, optionally limited by an IAM Condition.
resource "google_project_iam_member" "this" {
  project = var.project_id
  role    = var.role
  member  = var.member

  dynamic "condition" {
    for_each = var.condition_title == null ? [] : [1]
    content {
      title       = var.condition_title
      expression  = var.condition_expression
      description = var.condition_description
    }
  }
}
