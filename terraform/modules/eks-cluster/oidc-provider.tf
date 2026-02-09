data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Try to discover an existing provider by URL
data "aws_iam_openid_connect_provider" "existing" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Create only if lookup fails (i.e., existing.arn is empty)
resource "aws_iam_openid_connect_provider" "eks" {
  count = try(data.aws_iam_openid_connect_provider.existing.arn, "") == "" ? 1 : 0

  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}
