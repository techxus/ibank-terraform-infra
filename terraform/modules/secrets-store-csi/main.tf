resource "helm_release" "csi_driver" {
  name             = "csi-secrets-store"
  namespace        = "kube-system"
  create_namespace = false
  repository       = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart            = "secrets-store-csi-driver"

  set = [
    { name = "syncSecret.enabled",      value = "true" },
    { name = "enableSecretRotation",    value = "true" },
    { name = "rotationPollInterval",    value = "2m"   }
  ]
}



