#!/usr/bin/env bash
#
# install-prereqs.sh
# Installs Docker Desktop, kind, and kubectl on macOS (and Linux as bonus).
# Usage: chmod +x install-prereqs.sh && ./install-prereqs.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()   { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR ]${NC} $1"; }

header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE} $1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

header "Kubernetes Prerequisites Installer"
log "Detected OS: $OS ($ARCH)"

# ---------- macOS ----------
install_mac() {
  # 1. Homebrew
  header "Step 1/4: Homebrew"
  if command -v brew >/dev/null 2>&1; then
    ok "Homebrew already installed ($(brew --version | head -n1))"
  else
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add brew to PATH for Apple Silicon
    if [[ "$ARCH" == "arm64" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    ok "Homebrew installed"
  fi

  # 2. Docker Desktop
  header "Step 2/4: Docker Desktop"
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed ($(docker --version))"
  else
    log "Installing Docker Desktop..."
    brew install --cask docker
    ok "Docker Desktop installed"
    warn "You MUST launch Docker Desktop from Applications before continuing."
    warn "Waiting for Docker to start..."
    open -a Docker || true
    # Wait up to 60s for docker to become responsive
    for i in {1..30}; do
      if docker info >/dev/null 2>&1; then
        ok "Docker daemon is running"
        break
      fi
      sleep 2
      echo -n "."
    done
    echo ""
  fi

  # 3. kind
  header "Step 3/4: kind (Kubernetes in Docker)"
  if command -v kind >/dev/null 2>&1; then
    ok "kind already installed ($(kind --version))"
  else
    log "Installing kind..."
    brew install kind
    ok "kind installed"
  fi

  # 4. kubectl
  header "Step 4/4: kubectl"
  if command -v kubectl >/dev/null 2>&1; then
    ok "kubectl already installed ($(kubectl version --client --output=yaml 2>/dev/null | grep gitVersion | head -n1 | awk '{print $2}'))"
  else
    log "Installing kubectl..."
    brew install kubectl
    ok "kubectl installed"
  fi
}

# ---------- Linux ----------
install_linux() {
  # 1. Docker
  header "Step 1/3: Docker Engine"
  if command -v docker >/dev/null 2>&1; then
    ok "Docker already installed ($(docker --version))"
  else
    log "Installing Docker via get.docker.com script..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER" || true
    warn "You may need to log out and back in for docker group changes to apply."
    ok "Docker installed"
  fi

  # 2. kind
  header "Step 2/3: kind"
  if command -v kind >/dev/null 2>&1; then
    ok "kind already installed ($(kind --version))"
  else
    log "Installing kind..."
    KIND_ARCH="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && KIND_ARCH="arm64"
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-${KIND_ARCH}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    ok "kind installed"
  fi

  # 3. kubectl
  header "Step 3/3: kubectl"
  if command -v kubectl >/dev/null 2>&1; then
    ok "kubectl already installed"
  else
    log "Installing kubectl..."
    KC_ARCH="amd64"
    [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]] && KC_ARCH="arm64"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${KC_ARCH}/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    ok "kubectl installed"
  fi
}

# Route based on OS
case "$OS" in
  Darwin)
    install_mac
    ;;
  Linux)
    install_linux
    ;;
  *)
    err "Unsupported OS: $OS"
    err "This script supports macOS and Linux only. For Windows, use install-prereqs.bat."
    exit 1
    ;;
esac

# ---------- Verification ----------
header "Verification"
echo ""
log "Installed versions:"
echo ""

if command -v docker >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} docker:  $(docker --version 2>/dev/null || echo 'installed but not running')"
else
  echo -e "  ${RED}✗${NC} docker:  NOT FOUND"
fi

if command -v kind >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} kind:    $(kind --version)"
else
  echo -e "  ${RED}✗${NC} kind:    NOT FOUND"
fi

if command -v kubectl >/dev/null 2>&1; then
  echo -e "  ${GREEN}✓${NC} kubectl: $(kubectl version --client 2>/dev/null | head -n1)"
else
  echo -e "  ${RED}✗${NC} kubectl: NOT FOUND"
fi

echo ""
header "All Done!"
echo ""
log "Next steps:"
echo "  1. Make sure Docker Desktop is running (whale icon in menu bar)"
echo "  2. Create a cluster:  kind create cluster --name demo"
echo "  3. Verify:            kubectl get nodes"
echo ""
log "Docs: https://kind.sigs.k8s.io/docs/user/quick-start/"
echo ""
