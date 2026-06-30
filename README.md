# Homelab — Production-Grade Infrastructure Portfolio

A self-hosted, production-aligned platform built to demonstrate real-world DevOps, Cloud Engineering, and SRE skills. Every layer of this infrastructure — from bare metal provisioning to application deployment — is managed as code.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    ThinkPad (Control Plane)              │
│         Terraform · Ansible · kubectl · Git · SSH        │
└───────────────────┬─────────────────┬───────────────────┘
                    │                 │
       ┌────────────▼──────┐ ┌───────▼────────────┐
       │  HP EliteDesk G4  │ │   Intel NUC5i5RYH  │
       │  (Compute Node)   │ │   (Edge Node)       │
       │                   │ │                     │
       │  Proxmox VE 9.x   │ │  Proxmox VE 9.x    │
       │  ├─ k3s control   │ │  ├─ Pi-hole (DNS)   │
       │  ├─ k3s worker-1  │ │  ├─ Tailscale (VPN) │
       │  └─ k3s worker-2  │ │  ├─ PBS (Backups)   │
       │                   │ │  └─ Uptime Kuma      │
       │  i5-8500T 6c      │ │                     │
       │  32GB DDR4        │ │  i5-5250U 2c        │
       │  256GB NVMe       │ │  16GB DDR3          │
       └───────────────────┘ └────────────────────┘
```

**IP Scheme**

| Host | IP | Role |
|---|---|---|
| Gateway | 192.168.1.254 | ISP router |
| Intel NUC5 | 192.168.1.20 | Edge services / Proxmox host |
| Pi-hole LXC | 192.168.1.21 | DNS + ad blocking (CT 100) |
| Tailscale LXC | 192.168.1.22 | VPN mesh (CT 101) |
| Uptime Kuma LXC | 192.168.1.23 | Uptime monitoring (CT 102) |
| PBS LXC | 192.168.1.24 | Proxmox Backup Server (CT 103) |
| HP EliteDesk G4 | 192.168.1.10 | Compute / Proxmox (pending) |
| k3s control-plane VM | 192.168.1.30 | Kubernetes control (pending) |
| k3s worker-1 VM | 192.168.1.31 | Kubernetes worker (pending) |
| k3s worker-2 VM | 192.168.1.32 | Kubernetes worker (pending) |
| MetalLB pool | 192.168.1.40–49 | LoadBalancer IPs (pending) |

---

## Status

| Component | Status |
|---|---|
| ThinkPad control plane tooling | ✅ Done |
| NUC5 Proxmox VE 9.x | ✅ Done |
| Pi-hole LXC (CT 100) | ✅ Done |
| Tailscale LXC (CT 101) | ✅ Done |
| Uptime Kuma LXC (CT 102) | ✅ Done |
| PBS LXC (CT 103) | ✅ Done |
| Ansible baseline playbook | ✅ Done |
| G4 Proxmox | 🔲 Pending hardware |
| Terraform VM provisioning | 🔲 Pending G4 |
| k3s cluster | 🔲 Pending G4 |
| MetalLB + Traefik + ArgoCD | 🔲 Pending k3s |
| Prometheus + Grafana + Loki | 🔲 Pending k3s |
| PBS backup schedules | 🔲 Pending G4 |

---

## NUC5 Edge Node — Bootstrap Guide

> **Read this before touching the NUC5.** This documents the exact provisioning order required to bring the edge node from bare metal to fully Ansible-managed.

### Prerequisites

- Proxmox VE 9.x ISO flashed to USB (via Balena Etcher)
- ThinkPad bootstrap complete (`scripts/bootstrap-thinkpad.sh` run)
- Physical ethernet cable from NUC5 to network

### Step 1 — BIOS settings (F2 on boot)

| Setting | Value |
|---|---|
| Boot order | USB first |
| Secure Boot | Disabled |
| VT-x / Virtualization | Enabled |
| VT-d / IOMMU | Enabled |
| After power loss | Power On |

### Step 2 — Proxmox install

Use graphical installer with these values:

```
Hostname:  nuc-edge.home.lab
IP:        192.168.1.20/24
Gateway:   192.168.1.254
DNS:       8.8.8.8
```

> **Note:** The real gateway on this network is `192.168.1.254` (ISP router), not `.1`. Using `.1` will leave the NUC5 with no internet access after install.

### Step 3 — Post-install repo fixes (SSH into NUC5)

Proxmox VE 9.x uses `.sources` format (deb822), not `.list`. The enterprise repos must be blanked — `sed` on `.list` files won't work:

```bash
# Disable enterprise repos
echo "" > /etc/apt/sources.list.d/pve-enterprise.sources
echo "" > /etc/apt/sources.list.d/ceph.sources

# Add community repos
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

apt update && apt dist-upgrade -y
reboot
```

### Step 4 — LXC container provisioning

Download the Debian 12 template first:

```bash
pveam update
pveam download local debian-12-standard_12.12-1_amd64.tar.zst
```

Create all four containers (use `local-lvm` for rootfs — `local` does not support container directories on this setup):

```bash
# Pi-hole — CT 100
pct create 100 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname pihole --memory 512 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.21/24,gw=192.168.1.254 \
  --storage local-lvm --rootfs local-lvm:4 \
  --password --unprivileged 1 --features nesting=1 --onboot 1 --start 1

# Tailscale — CT 101
pct create 101 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname tailscale --memory 256 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.22/24,gw=192.168.1.254 \
  --storage local-lvm --rootfs local-lvm:2 \
  --password --unprivileged 1 --features nesting=1 --onboot 1 --start 1

# Add TUN device for Tailscale (unprivileged LXC requirement)
echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >> /etc/pve/lxc/101.conf
echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> /etc/pve/lxc/101.conf
pct stop 101 && pct start 101

# Uptime Kuma — CT 102
pct create 102 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname uptime-kuma --memory 512 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.23/24,gw=192.168.1.254 \
  --storage local-lvm --rootfs local-lvm:4 \
  --password --unprivileged 1 --features nesting=1 --onboot 1 --start 1

# PBS — CT 103
pct create 103 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname pbs --memory 1024 --cores 1 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.24/24,gw=192.168.1.254 \
  --storage local-lvm --rootfs local-lvm:8 \
  --password --unprivileged 1 --features nesting=1 --onboot 1 --start 1
```

### Step 5 — SSH bootstrap (one-time, run from ThinkPad)

Ansible needs SSH to manage containers. Fresh LXC templates don't have `openssh-server` and default to `PermitRootLogin prohibit-password`. The bootstrap script handles both:

```bash
# Copy and run bootstrap script on NUC5
scp scripts/bootstrap-lxc-ssh.sh root@192.168.1.20:/root/
ssh root@192.168.1.20 'chmod +x bootstrap-lxc-ssh.sh && ./bootstrap-lxc-ssh.sh'

# Copy SSH key to all containers
for ip in 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@$ip
done
```

### Step 6 — Run Ansible baseline

```bash
# Verify connectivity first
~/ansible-venv/bin/ansible all -i infra/ansible/inventory/hosts.yml -m ping

# Run baseline playbook
~/ansible-venv/bin/ansible-playbook -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/lxc-baseline.yml
```

### Known gotchas

**Ansible version:** ansible-core >= 2.18 required. Proxmox VE 9.x runs Python 3.13 — older Ansible versions fail with `ModuleNotFoundError: No module named 'ansible.module_utils.six.moves'`. The ThinkPad bootstrap script creates a Python 3.11 venv with ansible-core 2.19.x.

**PBS enterprise repo:** PBS containers install with an enterprise `.list` repo file alongside the `.sources` file. Both must be blanked before `apt update` works:
```bash
echo "" > /etc/apt/sources.list.d/pbs-enterprise.sources
echo "" > /etc/apt/sources.list.d/pbs-enterprise.list
```

**Container networking:** LXC containers are created with `gw=192.168.1.254` which matches the real network gateway. If containers lose their route after a restart, the Ansible baseline playbook will restore it on next run.

---

## Portfolio Projects

### Project 1 — GitOps Platform
**Stack:** Kubernetes · ArgoCD · Helm
**Goal:** All application deployments managed declaratively from Git. No manual `kubectl apply` in production.
**Skills demonstrated:** GitOps, Kubernetes, Helm, declarative infrastructure

### Project 2 — Observability Stack
**Stack:** Prometheus · Grafana · Loki · Alertmanager
**Goal:** Full cluster observability — metrics, logs, and alerting — deployed via GitOps.
**Skills demonstrated:** SRE practices, monitoring, alerting, log aggregation

### Project 3 — Backup & Disaster Recovery
**Stack:** Proxmox Backup Server · ZFS snapshots
**Goal:** Scheduled VM backups to NUC5 PBS, documented restore procedures, tested recovery drills.
**Skills demonstrated:** DR planning, RTO/RPO, operational discipline

### Project 4 — Incident Simulation Lab
**Stack:** Prometheus Alertmanager · Grafana · Postmortems
**Goal:** Deliberately break production services, detect via alerting, respond, write postmortems.
**Skills demonstrated:** SRE incident response, alert tuning, blameless postmortems

### Project 5 — Real Workload Operations
**Stack:** Factorio dedicated server · Kubernetes StatefulSet · PVCs
**Goal:** Operate a real user-facing stateful service with monitoring, backups, and defined SLOs.
**Skills demonstrated:** Stateful workload operations, SLO definition, real-world service management

### Project 6 — Security & Identity Layer
**Stack:** cert-manager · Sealed Secrets · Network Policies · Keycloak
**Goal:** TLS everywhere, secrets management, SSO, and network segmentation.
**Skills demonstrated:** Security engineering, zero-trust principles, identity management

---

## Tech Stack

| Category | Tools |
|---|---|
| Hypervisor | Proxmox VE 9.x (Debian 13 Trixie) |
| Containers (edge) | LXC (Pi-hole, Tailscale, Uptime Kuma, PBS) |
| Containers (k8s) | Kubernetes (k3s) |
| IaC | Terraform (Proxmox provider) |
| Configuration | Ansible (ansible-core 2.19.x) |
| GitOps | ArgoCD |
| Ingress | Traefik |
| Load Balancing | MetalLB |
| TLS | cert-manager |
| Metrics | Prometheus + Grafana |
| Logs | Loki + Promtail |
| Alerting | Alertmanager |
| Backups | Proxmox Backup Server |
| VPN | Tailscale |
| DNS | Pi-hole |
| Uptime | Uptime Kuma |

---

## Repo Structure

```
homelab/
├── infra/
│   ├── terraform/
│   │   ├── proxmox/        # Proxmox host configuration
│   │   └── k8s-vms/        # VM declarations for k3s nodes
│   └── ansible/
│       ├── inventory/      # Host inventory files
│       ├── playbooks/      # Ordered playbooks (lxc-baseline, k3s, etc.)
│       └── roles/          # Reusable Ansible roles
├── k8s/
│   ├── platform/
│   │   ├── argocd/         # ArgoCD install + app-of-apps
│   │   ├── metallb/        # MetalLB IP pool config
│   │   ├── traefik/        # Ingress controller
│   │   └── cert-manager/   # TLS certificate management
│   ├── monitoring/
│   │   ├── prometheus/     # Prometheus + Alertmanager rules
│   │   ├── grafana/        # Dashboards as code
│   │   └── loki/           # Log aggregation
│   ├── apps/               # User-facing applications
│   └── storage/            # PVCs and storage classes
├── docs/
│   ├── architecture/       # Architecture decision records (ADRs)
│   ├── runbooks/           # Operational runbooks
│   └── postmortems/        # Incident postmortems
├── scripts/
│   ├── bootstrap-thinkpad.sh   # One-time ThinkPad tooling install
│   └── bootstrap-lxc-ssh.sh   # One-time SSH bootstrap for LXC containers
└── diagrams/               # Architecture diagrams
```

---

## Build Order

1. **Phase 0** ✅ — ThinkPad tooling + NUC5 Proxmox + LXC edge services
2. **Phase 1** 🔲 — G4 Proxmox + Terraform VM provisioning + k3s cluster
3. **Phase 2** 🔲 — MetalLB + Traefik + cert-manager + ArgoCD
4. **Phase 3** 🔲 — Observability stack (Prometheus + Grafana + Loki)
5. **Phase 4** 🔲 — SRE layer (SLOs, alerting, incident simulation, DR drills)
6. **Phase 5** 🔲 — Security hardening + secrets management

---

## Running This Yourself

**Requirements:** Python 3.11+, ansible-core >= 2.18, Terraform >= 1.6, kubectl, Helm 3.x

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# 2. Bootstrap the ThinkPad control plane
chmod +x scripts/bootstrap-thinkpad.sh
./scripts/bootstrap-thinkpad.sh

# 3. Install Proxmox on NUC5 and G4 — see NUC5 Bootstrap Guide above

# 4. Bootstrap SSH on LXC containers (one-time manual step)
scp scripts/bootstrap-lxc-ssh.sh root@192.168.1.20:/root/
ssh root@192.168.1.20 'chmod +x bootstrap-lxc-ssh.sh && ./bootstrap-lxc-ssh.sh'

# 5. Copy SSH key to containers
for ip in 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@$ip
done

# 6. Run Ansible baseline
~/ansible-venv/bin/ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/lxc-baseline.yml

# 7. Provision k3s VMs via Terraform (after G4 arrives)
cd infra/terraform/k8s-vms
terraform init && terraform apply

# 8. Install k3s via Ansible
ansible-playbook -i inventory/hosts.yml playbooks/k3s.yml

# 9. Bootstrap ArgoCD
kubectl apply -k k8s/platform/argocd/
```

Full setup documentation is in [`docs/architecture/`](docs/architecture/) and [`docs/runbooks/`](docs/runbooks/).