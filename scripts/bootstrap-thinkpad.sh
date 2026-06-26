#!/usr/bin/env bash
# scripts/bootstrap-thinkpad.sh
# Run this once on your ThinkPad to install all required homelab tooling.
# Tested on Ubuntu 22.04 / Debian 12.

set -euo pipefail

echo "==> Installing homelab tooling on ThinkPad..."

# ── Tailscale ─────────────────────────────────────────────
echo "--> Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "    Run: sudo tailscale up"

# ── kubectl ───────────────────────────────────────────────
echo "--> Installing kubectl..."
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
kubectl version --client

# ── Terraform ─────────────────────────────────────────────
echo "--> Installing Terraform..."
sudo apt-get update -qq
sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -qq
sudo apt-get install -y terraform
terraform version

# ── Ansible ───────────────────────────────────────────────
echo "--> Installing Ansible..."
sudo apt-get install -y python3-pip
pip3 install --user ansible ansible-lint
ansible --version

# ── Helm ──────────────────────────────────────────────────
echo "--> Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# ── SSH key for homelab ───────────────────────────────────
echo "--> Generating homelab SSH key..."
if [ ! -f ~/.ssh/homelab_ed25519 ]; then
  ssh-keygen -t ed25519 -C "homelab" -f ~/.ssh/homelab_ed25519 -N ""
  echo "    SSH key generated at ~/.ssh/homelab_ed25519"
  echo "    Public key:"
  cat ~/.ssh/homelab_ed25519.pub
else
  echo "    SSH key already exists, skipping."
fi

echo ""
echo "==> Done. Next steps:"
echo "    1. sudo tailscale up"
echo "    2. Copy ~/.ssh/homelab_ed25519.pub into your Proxmox hosts"
echo "    3. Run: ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/baseline.yml"
