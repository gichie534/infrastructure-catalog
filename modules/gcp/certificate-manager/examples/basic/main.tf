provider "google" {
  project = var.project_id
  region  = var.region
}

# All-in-one: DNS authorizations + managed certs + certificate map + map entries for two hosts.
module "certs" {
  source = "../../"

  project_id = var.project_id
  name       = "example-public"

  certificates = {
    api = { domain = "api.${var.base_domain}" }
    app = { domain = "app.${var.base_domain}" }
  }
}

# The public zone plus the certs' validation CNAMEs. The validation record names are computed by
# Certificate Manager (unknown at plan time), so they go through cloud-dns's `validation_records`
# input — keyed by the cert label (static), with the computed name in the value. The cert module
# emits { name, type, data }; adapt `data` to cloud-dns's `rrdatas`.
module "dns" {
  source = "../../../cloud-dns"

  project_id = var.project_id
  name       = "example-public"
  dns_name   = "${var.base_domain}."
  visibility = "public"

  validation_records = {
    for label, rec in module.certs.dns_authorization_records :
    label => {
      name    = rec.name
      type    = rec.type
      rrdatas = [rec.data]
    }
  }
}
