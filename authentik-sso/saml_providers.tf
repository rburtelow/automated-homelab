# Create SAML property mappings for SonarQube
resource "authentik_property_mapping_provider_saml" "sonarqube_email" {
  name       = "SonarQube Email"
  saml_name  = "email"
  expression = "return user.email"
}

resource "authentik_property_mapping_provider_saml" "sonarqube_username" {
  name       = "SonarQube Username"
  saml_name  = "login"
  expression = "return user.username"
}

resource "authentik_property_mapping_provider_saml" "sonarqube_name" {
  name       = "SonarQube Name"
  saml_name  = "name"
  expression = "return user.name"
}

# Optional: Create custom property mapping for groups if needed
# resource "authentik_property_mapping_provider_saml" "sonarqube_groups" {
#   name       = "SonarQube Groups"
#   saml_name  = "groups"
#   expression = "return [group.name for group in user.ak_groups.all()]"
# }

resource "authentik_provider_saml" "provider_sonar-qube" {
    name                = "sonarqube"

    authorization_flow  = data.authentik_flow.default-provider-authorization-implicit-consent.id
    invalidation_flow   = data.authentik_flow.default-provider-authorization-implicit-consent.id

    acs_url    = "https://sonarqube.drongo-bangus.ts.net/oauth2/callback/saml"
    issuer     = "https://authentik.drongo-bangus.ts.net"
    sp_binding = "post"
    audience   = "sonarqube"

    # SonarQube expects these specific attributes
    assertion_valid_not_before = "minutes=-5"
    assertion_valid_not_on_or_after = "minutes=5"
    session_valid_not_on_or_after = "minutes=86400"

    # Signing configuration
    signing_kp = authentik_certificate_key_pair.saml_signing.id
    verification_kp = authentik_certificate_key_pair.saml_signing.id

    # NameID format - SonarQube typically uses email
    name_id_mapping = authentik_property_mapping_provider_saml.sonarqube_email.id

    property_mappings = [
        authentik_property_mapping_provider_saml.sonarqube_email.id,
        authentik_property_mapping_provider_saml.sonarqube_username.id,
        authentik_property_mapping_provider_saml.sonarqube_name.id,
    ]

    # Digest and signature algorithms
    digest_algorithm = "http://www.w3.org/2001/04/xmlenc#sha256"
    signature_algorithm = "http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"
}

# Create a self-signed certificate for SAML signing
resource "authentik_certificate_key_pair" "saml_signing" {
  name             = "sonarqube-saml-signing"
  certificate_data = tls_self_signed_cert.saml.cert_pem
  key_data         = tls_private_key.saml.private_key_pem
}

resource "tls_private_key" "saml" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "saml" {
  private_key_pem = tls_private_key.saml.private_key_pem

  subject {
    common_name  = "authentik.drongo-bangus.ts.net"
    organization = "Homelab"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "authentik_application" "application_sonar-qube" {
    name              = "sonarqube"
    slug              = "sonarqube"
    protocol_provider = authentik_provider_saml.provider_sonar-qube.id
}