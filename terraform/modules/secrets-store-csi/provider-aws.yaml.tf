resource "kubernetes_daemonset" "provider_aws" {
  metadata {
    name      = "secrets-store-csi-driver-provider-aws"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name" = "secrets-store-csi-driver-provider-aws"
    }
  }

  spec {
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "secrets-store-csi-driver-provider-aws"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "secrets-store-csi-driver-provider-aws"
        }
      }

      spec {
        service_account_name = "secrets-store-csi-driver"

        container {
          name  = "provider-aws"
          image = "public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.0"

          args = ["--provider-volume=/etc/kubernetes/secrets-store-csi-providers"]

          volume_mount {
            name       = "providers-dir"
            mount_path = "/etc/kubernetes/secrets-store-csi-providers"
          }
        }

        volume {
          name = "providers-dir"
          host_path {
            path = "/etc/kubernetes/secrets-store-csi-providers"
            type = "DirectoryOrCreate"
          }
        }
      }
    }
  }
}
