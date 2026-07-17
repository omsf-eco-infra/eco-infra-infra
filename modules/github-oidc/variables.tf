variable "prevent_destroy" {
  description = "Protect the OIDC provider from deletion. Set to false only for disposable fixtures."
  type        = bool
  default     = true
}
