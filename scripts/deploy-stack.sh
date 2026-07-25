#!/usr/bin/env bash
##############################################################################
#  CloudPulse – Full Stack Deployment Script
#  deploy-stack.sh  (updated for real BodhGanga structure)
#
#  BodhGanga real structure:
#    bodhganga/backend/   → Spring Boot 3.4.5, Java 17, MongoDB, port 9090
#    bodhganga/frontend/  → React (Vite) + Nginx, port 80
#    MongoDB              → mongo:7.0 StatefulSet, port 27017
#
#  Prerequisites:
#    - Minikube running (minikube status)
#    - kubectl configured
#    - Helm 3 installed
##############################################################################

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BODHGANGA_DIR="$PROJECT_ROOT/bodhganga"

# ── Verify the cluster is reachable ───────────────────────────────────────────
info "Verifying Minikube cluster..."
kubectl cluster-info --request-timeout=5s || error "Cluster not reachable. Run: minikube start"

##############################################################################
# PHASE 1 – Point Docker at Minikube's daemon & build images
##############################################################################
info "Phase 1 – Building Docker images inside Minikube..."
eval "$(minikube docker-env)"

# Backend image
info "  Building bodhganga-backend:1.0.0 ..."
docker build -t bodhganga-backend:1.0.0 "$BODHGANGA_DIR/backend/"
success "  Backend image built."

# Frontend image (pass the backend API URL as a build arg)
info "  Building bodhganga-frontend:1.0.0 ..."
docker build \
  --build-arg VITE_API_BASE_URL="http://$(minikube ip):30090/api" \
  -t bodhganga-frontend:1.0.0 \
  "$BODHGANGA_DIR/frontend/"
success "  Frontend image built."

##############################################################################
# PHASE 2 – Namespace & Secrets
##############################################################################
info "Phase 2 – Creating namespace and secrets..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"

# Apply the Secret template (users must populate real values first)
if kubectl get secret bodhganga-secrets -n bodhganga &>/dev/null; then
  warn "Secret 'bodhganga-secrets' already exists. Skipping creation."
  warn "To update: kubectl delete secret bodhganga-secrets -n bodhganga && kubectl apply -f k8s/Secret.yaml"
else
  kubectl apply -f "$PROJECT_ROOT/k8s/Secret.yaml"
  success "Secret 'bodhganga-secrets' created."
fi

##############################################################################
# PHASE 3 – Deploy BodhGanga (Backend + Frontend + MongoDB)
##############################################################################
info "Phase 3 – Deploying BodhGanga application stack..."
kubectl apply -f "$PROJECT_ROOT/k8s/Deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/Service.yaml"
success "Deployment and Service manifests applied."

info "Waiting for MongoDB to be ready..."
kubectl rollout status statefulset/bodhganga-mongodb \
  --namespace bodhganga --timeout=120s

info "Waiting for Backend pods to be ready (timeout: 4 min)..."
kubectl rollout status deployment/bodhganga-backend \
  --namespace bodhganga --timeout=240s

info "Waiting for Frontend pods to be ready..."
kubectl rollout status deployment/bodhganga-frontend \
  --namespace bodhganga --timeout=120s

success "All BodhGanga workloads are running."

echo ""
kubectl get pods -n bodhganga
echo ""

##############################################################################
# PHASE 4 – Helm: Add repos & install kube-prometheus-stack
##############################################################################
info "Phase 4 – Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update
success "Helm repos updated."

info "Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cloudpulse-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$PROJECT_ROOT/helm/prometheus-values.yaml" \
  --wait \
  --timeout 10m

success "kube-prometheus-stack installed."

##############################################################################
# PHASE 5 – Apply Monitoring CRDs
##############################################################################
info "Phase 5 – Applying ServiceMonitor, PrometheusRules, AlertmanagerConfig..."
kubectl apply -f "$PROJECT_ROOT/k8s/ServiceMonitor.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/PrometheusRule.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/AlertmanagerConfig.yaml"
success "Monitoring resources applied."

##############################################################################
# SUMMARY
##############################################################################
MINIKUBE_IP=$(minikube ip)

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      CloudPulse + BodhGanga Deployment COMPLETE 🚀              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}BodhGanga Access:${NC}"
echo "  Frontend   → http://$MINIKUBE_IP:30080"
echo "  Backend API→ kubectl port-forward svc/bodhganga-backend-svc 9090:9090 -n bodhganga"
echo "  Metrics    → http://localhost:9090/actuator/prometheus  (after port-forward)"
echo ""
echo -e "${YELLOW}Observability Stack:${NC}"
echo "  Grafana    → kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring"
echo "               http://localhost:3000  |  admin / CloudPulse@2024!"
echo "  Prometheus → kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring"
echo "  Alertmgr   → kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring"
echo ""
echo -e "${YELLOW}Import Grafana Dashboard:${NC}"
echo "  JVM (Micrometer)     → ID: 4701  (recommended for BodhGanga)"
echo "  Spring Boot Stats    → ID: 12900"
echo "  Kubernetes Overview  → ID: 7249"
echo ""
