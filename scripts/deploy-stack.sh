#!/usr/bin/env bash
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

info "Verifying Minikube cluster..."
kubectl cluster-info --request-timeout=5s || error "Cluster not reachable. Run: minikube start"

info "Phase 1 – Building Docker images..."
eval "$(minikube docker-env)"

info "  Building bodhganga-backend:1.0.0 ..."
docker build -t bodhganga-backend:1.0.0 "$BODHGANGA_DIR/backend/"
success "  Backend image built."

info "  Building bodhganga-frontend:1.0.0 ..."
docker build \
  --build-arg VITE_API_BASE_URL="http://$(minikube ip):30090/api" \
  -t bodhganga-frontend:1.0.0 \
  "$BODHGANGA_DIR/frontend/"
success "  Frontend image built."

info "Phase 2 – Creating namespace and secrets..."
kubectl apply -f "$PROJECT_ROOT/k8s/namespace.yaml"

if kubectl get secret bodhganga-secrets -n bodhganga &>/dev/null; then
  warn "Secret 'bodhganga-secrets' already exists. Skipping."
else
  kubectl apply -f "$PROJECT_ROOT/k8s/Secret.yaml"
  success "Secret created."
fi

info "Phase 3 – Deploying BodhGanga stack..."
kubectl apply -f "$PROJECT_ROOT/k8s/Deployment.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/Service.yaml"
success "Deployment and Service applied."

info "Waiting for MongoDB..."
kubectl rollout status statefulset/bodhganga-mongodb \
  --namespace bodhganga --timeout=120s

info "Waiting for Backend pods..."
kubectl rollout status deployment/bodhganga-backend \
  --namespace bodhganga --timeout=240s

info "Waiting for Frontend pods..."
kubectl rollout status deployment/bodhganga-frontend \
  --namespace bodhganga --timeout=120s

success "All BodhGanga workloads are running."
kubectl get pods -n bodhganga

info "Phase 4 – Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update
success "Helm repos updated."

info "Phase 5 – Installing kube-prometheus-stack..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install cloudpulse-prometheus \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values "$PROJECT_ROOT/helm/prometheus-values.yaml" \
  --wait \
  --timeout 10m

success "kube-prometheus-stack installed."

info "Phase 6 – Applying monitoring resources..."
kubectl apply -f "$PROJECT_ROOT/k8s/ServiceMonitor.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/PrometheusRule.yaml"
kubectl apply -f "$PROJECT_ROOT/k8s/AlertmanagerConfig.yaml"
success "Monitoring resources applied."

MINIKUBE_IP=$(minikube ip)

echo ""
echo -e "${GREEN}CloudPulse + BodhGanga Deployment COMPLETE${NC}"
echo ""
echo -e "${YELLOW}BodhGanga:${NC}"
echo "  Frontend   → http://$MINIKUBE_IP:30080"
echo "  Backend    → kubectl port-forward svc/bodhganga-backend-svc 9090:9090 -n bodhganga"
echo "  Metrics    → http://localhost:9090/actuator/prometheus (after port-forward)"
echo ""
echo -e "${YELLOW}Observability:${NC}"
echo "  Grafana    → kubectl port-forward svc/cloudpulse-prometheus-grafana 3000:80 -n monitoring"
echo "               http://localhost:3000  |  admin / CloudPulse@2024!"
echo "  Prometheus → kubectl port-forward svc/cloudpulse-prometheus-kube-prome-prometheus 9091:9090 -n monitoring"
echo "  Alertmgr   → kubectl port-forward svc/cloudpulse-prometheus-kube-prome-alertmanager 9093:9093 -n monitoring"
echo ""
echo -e "${YELLOW}Grafana Dashboard IDs:${NC}  4701 (JVM)  12900 (Spring Boot)  7249 (Kubernetes)"
