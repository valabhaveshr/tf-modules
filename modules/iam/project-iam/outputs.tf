###############################################################################
# outputs.tf - Output contract for the iam/project-iam module.
#
# NOTE: One module call = one grant, so every output is a single value. With
# the portal's `for_each`, read them as module.<name>["<instance>"].<output>.
###############################################################################

output "id" {
  description = "The grant's resource ID, as the provider builds it from the project, role, member and (if set) condition title."
  value       = google_project_iam_member.this.id
}

output "etag" {
  description = "The etag of the project's IAM policy after the grant was applied."
  value       = google_project_iam_member.this.etag
}

output "project" {
  description = "The project the role is granted on."
  value       = google_project_iam_member.this.project
}

output "role" {
  description = "The granted role."
  value       = google_project_iam_member.this.role
}

output "member" {
  description = "The principal that received the role."
  value       = google_project_iam_member.this.member
}

output "condition_title" {
  description = "The title of the IAM Condition on the grant, or null for an unconditional grant."
  value       = try(google_project_iam_member.this.condition[0].title, null)
}
