variable "prevent_destroy" {
  description = "Protect the OIDC provider from deletion. Set to false only for disposable fixtures. Changing this value for an existing provider requires a state migration."
  type        = bool
  default     = true
}
