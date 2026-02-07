############################################
# IRSA assume role policy for the controller
############################################
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

############################################
# Download the official policy and create it
############################################
data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "controller" {
  name   = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.lbc_iam_policy.response_body

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}

############################################
# ServiceAccount annotated with IRSA role
############################################
resource "kubernetes_service_account_v1" "sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.controller.arn
    }
    labels = {
      "app.kubernetes.io/name" = "aws-load-balancer-controller"
    }
  }
}

############################################
# Helm install (waits for IAM + SA)
############################################
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.region
      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.sa.metadata[0].name
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller_attach,
    kubernetes_service_account_v1.sa
  ]
}
