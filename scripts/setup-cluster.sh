#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

[[ $EUID -ne 0 ]] && error "Run this script as root: sudo $0 $*"

USE_K3S=false
for arg in "$@"; do
  [[ "$arg" == "--k3s" ]] && USE_K3S=true
done

ARCH=$(uname -m)
CODENAME=$(lsb_release -sc 2>/dev/null || echo "focal")

info "CloudPulse Cluster Bootstrap starting..."
info "Mode: $([ "$USE_K3S" == "true" ] && echo 'K3s' || echo 'Minikube')"

apt-get update -y
apt-get install -y \
  apt-transport-https ca-certificates curl gnupg lsb-release \
  git jq unzip conntrack socat ebtables ipset
success "System packages installed."

if command -v docker &>/dev/null; then
  warn "Docker already installed. Skipping."
else
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    warn "Added $SUDO_USER to the docker group. Re-login required."
  fi
  success "Docker CE installed."
fi

if command -v kubectl &>/dev/null; then
  warn "kubectl already installed. Skipping."
else
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --quiet
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl kubectl.sha256
  success "kubectl installed."
fi

if command -v helm &>/dev/null; then
  warn "Helm already installed. Skipping."
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  success "Helm installed."
fi

if [[ "$USE_K3S" == "false" ]]; then
  if command -v minikube &>/dev/null; then
    warn "Minikube already installed. Skipping."
  else
    curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
    success "Minikube installed."
  fi
  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo -u "$SUDO_USER" minikube start \
      --driver=docker \
      --cpus=4 \
      --memory=6144 \
      --disk-size=30g \
      --kubernetes-version=stable \
      --addons=ingress,metrics-server \
      --embed-certs
    success "Minikube cluster started."
    sudo -u "$SUDO_USER" kubectl get nodes
  else
    warn "Cannot start Minikube as root. Run manually:"
    echo "  minikube start --driver=docker --cpus=4 --memory=6144 --addons=ingress,metrics-server"
  fi
else
  if systemctl is-active --quiet k3s 2>/dev/null; then
    warn "K3s is already running. Skipping."
  else
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --disable traefik \
      --write-kubeconfig-mode 644" sh -
    systemctl enable k3s
    mkdir -p /root/.kube
    cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
    if [[ -n "${SUDO_USER:-}" ]]; then
      mkdir -p /home/"$SUDO_USER"/.kube
      cp /etc/rancher/k3s/k3s.yaml /home/"$SUDO_USER"/.kube/config
      chown "$SUDO_USER":"$SUDO_USER" /home/"$SUDO_USER"/.kube/config
    fi
    success "K3s installed."
  fi
  kubectl get nodes
fi

echo ""
echo -e "${GREEN}Bootstrap COMPLETE${NC}"
echo -e "  Docker  : $(docker --version)"
echo -e "  kubectl : $(kubectl version --client --short 2>/dev/null)"
echo -e "  Helm    : $(helm version --short)"
echo ""
echo -e "${YELLOW}Next:${NC} Run ./scripts/deploy-stack.sh"
