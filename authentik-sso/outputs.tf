# Output the SAML metadata URL for SonarQube configuration
output "sonarqube_saml_metadata_url" {
  description = "SAML metadata URL for SonarQube"
  value       = "${var.authentik_url}/api/v3/providers/saml/${authentik_provider_saml.provider_sonar-qube.id}/metadata/?download"
}

# Output the ACS URL (Assertion Consumer Service URL)
output "sonarqube_acs_url" {
  description = "ACS URL configured for SonarQube"
  value       = authentik_provider_saml.provider_sonar-qube.acs_url
}

# Output the Entity ID / Issuer
output "sonarqube_entity_id" {
  description = "Entity ID (Issuer) for Authentik SAML"
  value       = authentik_provider_saml.provider_sonar-qube.issuer
}

# Output the application URL
output "sonarqube_application_url" {
  description = "Application launch URL in Authentik"
  value       = "${var.authentik_url}/application/o/${authentik_application.application_sonar-qube.slug}/"
}

# Output the SAML certificate
output "sonarqube_saml_certificate" {
  description = "SAML signing certificate (base64 encoded)"
  value       = base64encode(tls_self_signed_cert.saml.cert_pem)
  sensitive   = true
}

