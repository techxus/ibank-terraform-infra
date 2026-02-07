terraform {
  required_providers {
    aws  = { source = "hashicorp/aws",  version = ">= 5.0.0, < 6.0.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.20.0, < 3.0.0" }
    helm = { source = "hashicorp/helm", version = ">= 3.0.0, < 4.0.0" }
    http = { source = "hashicorp/http" }
  }
}
