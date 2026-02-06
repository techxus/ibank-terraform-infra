provider "aws" {
  region = var.region
}

module "eks" {
  source            = "../../modules/eks-cluster"
  region            = var.region
  cluster_name      = var.cluster_name
  allowed_api_cidrs = var.allowed_api_cidrs
}


# Route53 zone lookup
data "aws_route53_zone" "public" {
  name         = var.public_zone_name
  private_zone = false
}

# ACM cert for api.dev.bankit.cloud
resource "aws_acm_certificate" "api_cert" {
  domain_name       = var.api_hostname
  validation_method = "DNS"
}

resource "aws_route53_record" "api_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.value]
}

resource "aws_acm_certificate_validation" "api_cert" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for r in aws_route53_record.api_cert_validation : r.fqdn]
}

module "alb_controller" {
  source       = "../../modules/alb-controller"
  cluster_name = module.eks.cluster_name
  region       = var.region

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # these can stay for now even if not used; optional cleanup later
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_certificate_authority_data

  providers = {
    aws        = aws
    kubernetes = kubernetes
    helm       = helm
  }
}

module "argocd" {
  source       = "../../modules/argocd-bootstrap"
  cluster_name = module.eks.cluster_name
  region       = var.region

  cluster_endpoint = module.eks.cluster_endpoint
  cluster_ca_data  = module.eks.cluster_certificate_authority_data

  gitops_repo_url        = var.gitops_repo_url
  gitops_target_revision = var.gitops_target_revision
  gitops_root_path       = var.gitops_root_path

  providers = {
    aws        = aws
    kubernetes = kubernetes
    helm       = helm
  }
}



