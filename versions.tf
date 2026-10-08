terraform {
  required_version = ">= 1.5"

  required_providers {
    verda = {
      source  = "verda-cloud/verda"
      version = "~> 1.1"
    }
  }
}

# Credentials are read from the VERDA_CLIENT_ID and VERDA_CLIENT_SECRET
# environment variables. Create them in the Verda console under Keys.
provider "verda" {}
