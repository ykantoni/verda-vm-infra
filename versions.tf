terraform {
  required_version = ">= 1.5"

  required_providers {
    verda = {
      source  = "verda-cloud/verda"
      version = "~> 1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  # path is intentionally omitted: the local backend then defaults to
  # "terraform.tfstate", same as before. The verda-cloud repo's Justfile
  # (`just vm-init`) supplies it explicitly via -backend-config instead, so
  # this repo's state always lives at the one path verda-k8s-infra expects
  # — a plain `terraform init` still works, it just uses the plain default.
  backend "local" {}
}

# Credentials are read from the VERDA_CLIENT_ID and VERDA_CLIENT_SECRET
# environment variables. Create them in the Verda console under Keys.
provider "verda" {}
