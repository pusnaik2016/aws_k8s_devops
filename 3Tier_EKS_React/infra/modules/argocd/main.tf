# =============================================================================
# ArgoCD Module — GitOps deployment via Helm
# Project: 3-Tier EKS Application
# Author: Pushparaj Naik
# =============================================================================

# --- ArgoCD Namespace ---
resource "kubernetes_namespace" "argocd" {
  count = var.enable ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = "argocd"
      Environment                    = var.environment
      Owner                          = "pushparaj"
    }
  }
}

# --- ArgoCD Helm Release ---
resource "helm_release" "argocd" {
  count = var.enable ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd[0].metadata[0].name

  wait    = true
  timeout = 600

  # --- Server Configuration ---
  set {
    name  = "server.insecure"
    value = "true"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # --- Server Resources ---
  set {
    name  = "server.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "server.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "server.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "server.resources.limits.memory"
    value = "512Mi"
  }

  # --- Repo Server Resources ---
  set {
    name  = "repoServer.resources.requests.cpu"
    value = "100m"
  }

  set {
    name  = "repoServer.resources.requests.memory"
    value = "128Mi"
  }

  set {
    name  = "repoServer.resources.limits.cpu"
    value = "500m"
  }

  set {
    name  = "repoServer.resources.limits.memory"
    value = "512Mi"
  }

  # --- Application Controller Resources ---
  set {
    name  = "controller.resources.requests.cpu"
    value = "250m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "256Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # --- Metrics for Prometheus ---
  set {
    name  = "server.metrics.enabled"
    value = "true"
  }

  set {
    name  = "server.metrics.serviceMonitor.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }

  set {
    name  = "repoServer.metrics.enabled"
    value = "true"
  }

  # --- Configs ---
  set {
    name  = "configs.params.timeout\\.reconciliation"
    value = "180"
  }

  set {
    name  = "global.additionalLabels.app\\.kubernetes\\.io/managed-by"
    value = "terraform"
  }
}

# --- App-of-Apps Bootstrap ---
resource "kubernetes_manifest" "app_of_apps" {
  count = var.enable ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"

    metadata = {
      name      = "3tier-app-of-apps"
      namespace = var.namespace
      labels = {
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/part-of"    = "devops-quiz"
      }
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
    }

    spec = {
      project = "default"

      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_target_revision
        path           = "argocd/apps"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.namespace
      }

      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true # Drift detection
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "PruneLast=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}
