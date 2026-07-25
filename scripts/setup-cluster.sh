#!/usr/bin/env bash
##############################################################################
#  CloudPulse – Cluster Bootstrap Script
#  setup-cluster.sh
#
#  Installs on a fresh Debian / Ubuntu VPS:
#    1. Docker CE (with rootless daemon config)
#    2. kubectl (latest stable)
#    3. Helm 3
#    4. Minikube  (flag: --driver=docker, for local dev)
#       OR K3s    (flag: --k3s, for VPS / CI environments)
#
#  Usage:
#    chmod +x setup-cluster.sh
#    sudo ./setup-cluster.sh             # installs Minikube (default)
#    sudo ./setup-cluster.sh --k3s       # installs K3s instead
##############################################################################

set -euo pipefail

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m' # No Colour
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Root check ───────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Run this script as root: sudo $0 $*"

# ─── Parse flags ──────────────────────────────────────────────────────────────
USE_K3S=false
for arg in "$@"; do
  [[ "$arg" == "--k3s" ]] && USE_K3S=true
done

ARCH=$(uname -m)
OS=$(lsb_release -si 2>/dev/null || echo "Unknown")
CODENAME=$(lsb_release -sc 2>/dev/null || echo "focal")

info "CloudPulse Cluster Bootstrap starting..."
info "OS: $OS  |  Codename: $CODENAME  |  Arch: $ARCH"
info "Mode: $([ "$USE_K3S" == "true" ] && echo 'K3s (VPS)' || echo 'Minikube (Local)')"
echo ""

##############################################################################
# STEP 1 – System Prerequisites
##############################################################################
info "Step 1/6 – Updating system packages..."
apt-get update -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  jq \
  unzip \
  conntrack \
  socat \
  ebtables \
  ipset
success "System packages installed."

##############################################################################
# STEP 2 – Docker CE
##############################################################################
info "Step 2/6 – Installing Docker CE..."

if command -v docker &>/dev/null; then
  warn "Docker already installed: $(docker --version). Skipping."
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

  # Allow current non-root user (if any) to run docker
  if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    warn "Added $SUDO_USER to the docker group. Re-login for it to take effect."
  fi

  success "Docker CE installed: $(docker --version)"
fi

##############################################################################
# STEP 3 – kubectl
##############################################################################
info "Step 3/6 – Installing kubectl..."

if command -v kubectl &>/dev/null; then
  warn "kubectl already installed: $(kubectl version --client --short 2>/dev/null). Skipping."
else
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  info "Downloading kubectl $KUBECTL_VERSION..."
  curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"
  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --quiet
  install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl kubectl.sha256
  success "kubectl installed: $(kubectl version --client --short 2>/dev/null)"
fi

##############################################################################
# STEP 4 – Helm 3
##############################################################################
info "Step 4/6 – Installing Helm 3..."

if command -v helm &>/dev/null; then
  warn "Helm already installed: $(helm version --short). Skipping."
else
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  success "Helm installed: $(helm version --short)"
fi

##############################################################################
# STEP 5A – Minikube  (default)
##############################################################################
if [[ "$USE_K3S" == "false" ]]; then
  info "Step 5/6 – Installing Minikube..."

  if command -v minikube &>/dev/null; then
    warn "Minikube already installed: $(minikube version --short). Skipping."
  else
    curl -sLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    install minikube-linux-amd64 /usr/local/bin/minikube
    rm -f minikube-linux-amd64
    success "Minikube installed: $(minikube version --short)"
  fi

  info "Step 6/6 – Starting Minikube cluster..."
  # Run as the SUDO_USER, not as root (Minikube dislikes root)
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
    warn "Cannot start Minikube as root. Run manually after setup:"
    echo "  minikube start --driver=docker --cpus=4 --memory=6144 --addons=ingress,metrics-server"
  fi

##############################################################################
# STEP 5B – K3s  (--k3s flag)
##############################################################################
else
  info "Step 5/6 – Installing K3s (lightweight production Kubernetes)..."

  if systemctl is-active --quiet k3s 2>/dev/null; then
    warn "K3s is already running. Skipping installation."
  else
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
      --disable traefik \
      --write-kubeconfig-mode 644" sh -
    systemctl enable k3s

    # Copy kubeconfig for the current user
    mkdir -p /root/.kube
    cp /etc/rancher/k3s/k3s.yaml /root/.kube/config

    if [[ -n "${SUDO_USER:-}" ]]; then
      mkdir -p /home/"$SUDO_USER"/.kube
      cp /etc/rancher/k3s/k3s.yaml /home/"$SUDO_USER"/.kube/config
      chown "$SUDO_USER":"$SUDO_USER" /home/"$SUDO_USER"/.kube/config
    fi

    success "K3s installed and running."
  fi

  info "Step 6/6 – Verifying K3s cluster nodes..."
  kubectl get nodes
fi

##############################################################################
# SUMMARY
##############################################################################
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          CloudPulse Cluster Bootstrap COMPLETE               ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Docker  : $(docker --version)"
echo -e "  kubectl : $(kubectl version --client --short 2>/dev/null)"
echo -e "  Helm    : $(helm version --short)"
if [[ "$USE_K3S" == "false" ]]; then
  echo -e "  Minikube: $(minikube version --short)"
else
  echo -e "  K3s     : $(k3s --version | head -1)"
fi
echo ""
echo -e "${YELLOW}Next Step:${NC}  cd into the CloudPulse directory and run:"
echo -e "           kubectl apply -f k8s/namespace.yaml"
echo ""
