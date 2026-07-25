#!/usr/bin/env bash
##############################################################################
#  CloudPulse – Full Observability Stack Deployment Script
#  deploy-stack.sh
#
#  Run this script after setup-cluster.sh has completed and your cluster
#  is healthy (kubectl get nodes shows Ready).
#
#  Usage:
#    chmod +x scripts/deploy-stack.sh
#    ./scripts/deploy-stack.sh
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

##############################################################################
# PHASE 1 – Build & Load BodhGanga Docker Image into Minikube
##############################################################################
info "Phase 1 – Building BodhGanga Docker image..."

cd "$PROJECT_ROOT/bodhganga-app"

# Build the image using Docker (Minikube has its own Docker daemon)
eval "$(minikube docker-env)"
docker build -t bodhganga-app:1.0.0 .

success "Image bodhganga-app:1.0.0 loaded into Minikube."

cd "$PROJECT_ROOT"

##############################################################################
# PHASE 2 – Create Namespace
##############################################################################
info "Phase 2 – Creating Kubernetes namespace..."
kubectl apply -f k8s/namespace.yaml
success "Namespace 'bodhganga' ready."

##############################################################################
# PHASE 3 – Deploy BodhGanga Application
##############################################################################
info "Phase 3 – Deploying BodhGanga application..."
kubectl apply -f k8s/Deployment.yaml
kubectl apply -f k8s/Service.yaml
success "BodhGanga Deployment and Service applied."

info "Waiting for BodhGanga pods to be ready (timeout: 3 min)..."
kubectl rollout status deployment/bodhganga \
  --namespace bodhganga \
  --timeout=180s
success "BodhGanga rollout complete."

##############################################################################
# PHASE 4 – Add Helm Repositories
##############################################################################
info "Phase 4 – Adding Helm repositories..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

success "Helm repositories updated."

##############################################################################
# PHASE 5 – Install kube-prometheus-stack
##############################################################################
info "Phase 5 – Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)..."

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cloudpulse-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values helm/prometheus-values.yaml \
  --wait \
  --timeout 10m

success "kube-prometheus-stack installed."

##############################################################################
# PHASE 6 – Apply ServiceMonitor and Alert Rules
##############################################################################
info "Phase 6 – Applying ServiceMonitor and PrometheusRules..."
kubectl apply -f k8s/ServiceMonitor.yaml
kubectl apply -f k8s/PrometheusRule.yaml
kubectl apply -f k8s/AlertmanagerConfig.yaml
success "Monitoring resources applied."

##############################################################################
# SUMMARY
##############################################################################
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        CloudPulse Stack Deployment COMPLETE 🚀               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  BodhGanga pods:"
kubectl get pods -n bodhganga
echo ""
echo -e "  Monitoring pods:"
kubectl get pods -n monitoring
echo ""
echo -e "${YELLOW}Access Grafana:${NC}"
echo "  kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring"
echo "  Open: http://localhost:3000  |  admin / CloudPulse@2024!"
echo ""
echo -e "${YELLOW}Access Prometheus:${NC}"
echo "  kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring"
echo "  Open: http://localhost:9091"
echo ""
echo -e "${YELLOW}Access Alertmanager:${NC}"
echo "  kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring"
echo "  Open: http://localhost:9093"
