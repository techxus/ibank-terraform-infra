resource "kubernetes_namespace_v1" "platform" {
  metadata {
    name = "platform"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.platform.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.11"

  values = [
    yamlencode({
      crds = {
        install = true
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]
}

resource "null_resource" "wait_for_argocd_crds" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = "kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=300s"
  }
}

# Write the root Application YAML to a local file
resource "local_file" "root_app_yaml" {
  filename = "${path.module}/ibank-root-app.yaml"
  content  = <<-YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ibank-root
  namespace: ${kubernetes_namespace_v1.platform.metadata[0].name}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ${var.gitops_repo_url}
    targetRevision: ${var.gitops_target_revision}
    path: ${var.gitops_root_path}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${kubernetes_namespace_v1.platform.metadata[0].name}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
YAML
}

# Apply root Application AFTER CRD exists
resource "null_resource" "apply_root_app" {
  depends_on = [
    null_resource.wait_for_argocd_crds,
    local_file.root_app_yaml
  ]

  provisioner "local-exec" {
    command = "kubectl apply -f ${local_file.root_app_yaml.filename}"
  }
}
