# Homelab — Production-Grade Infrastructure Portfolio

A self-hosted, production-aligned platform built to demonstrate real-world DevOps, Cloud Engineering, and SRE skills. Every layer of this infrastructure — from bare metal provisioning to application deployment — is managed as code.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ThinkPad (Control Plane)                      │
│    Terraform · Ansible 2.19 · kubectl · Helm · Git · Tailscale  │
└───────────────────┬──────────────────────┬───────────────────────┘
                    │                      │
       ┌────────────▼──────────┐  ┌───────▼────────────────┐
       │   HP EliteDesk G4     │  │   Intel NUC5i5RYH      │
       │   Compute Node        │  │   Edge Node             │
       │                       │  │                         │
       │   Proxmox VE 9.x      │  │   Proxmox VE 9.x       │
       │   ├─ k3s-cp-01 (.30)  │  │   ├─ Pi-hole    (.21)  │
       │   ├─ k3s-w-01  (.31)  │  │   ├─ Tailscale  (.22)  │
       │   └─ k3s-w-02  (.32)  │  │   ├─ Uptime Kuma(.23)  │
       │                       │  │   ├─ PBS        (.24)  │
       │   i5-8500T · 6 cores  │  │   ├─ Prometheus (.25)  │
       │   16GB DDR4           │  │   ├─ Grafana    (.26)  │
       │   256GB NVMe          │  │   └─ Loki       (.27)  │
       └───────────────────────┘  └────────────────────────┘
```

**IP Scheme**

| Host | IP | Role |
|---|---|---|
| Gateway | 192.168.1.254 | ISP router |
| HP EliteDesk G4 | 192.168.1.10 | Compute node — Proxmox host |
| Intel NUC5 | 192.168.1.20 | Edge node — Proxmox host |
| Pi-hole LXC | 192.168.1.21 | DNS + ad blocking (CT 100) |
| Tailscale LXC | 192.168.1.22 | VPN mesh (CT 101) |
| Uptime Kuma LXC | 192.168.1.23 | Uptime monitoring (CT 102) |
| PBS LXC | 192.168.1.24 | Proxmox Backup Server (CT 103) |
| Prometheus LXC | 192.168.1.25 | Metrics collection (CT 104) |
| Grafana LXC | 192.168.1.26 | Dashboards (CT 105) |
| Loki LXC | 192.168.1.27 | Log aggregation (CT 106) |
| k3s control-plane | 192.168.1.30 | Kubernetes control plane (VM 300) |
| k3s worker-1 | 192.168.1.31 | Kubernetes worker (VM 301) |
| k3s worker-2 | 192.168.1.32 | Kubernetes worker (VM 302) |
| MetalLB pool | 192.168.1.40-49 | LoadBalancer IPs |
| Traefik | 192.168.1.40 | Ingress controller |
| ArgoCD | 192.168.1.41 | GitOps engine |

---

## Status

| Component | Status |
|---|---|
| ThinkPad control plane tooling | done |
| NUC5 Proxmox VE 9.x | done |
| Pi-hole LXC (CT 100) | done |
| Tailscale LXC (CT 101) | done |
| Uptime Kuma LXC (CT 102) | done |
| PBS LXC (CT 103) | done |
| Prometheus LXC (CT 104) | done |
| Grafana LXC (CT 105) | done |
| Loki LXC (CT 106) | done |
| Ansible baseline playbook | done |
| Ansible observability playbook | done |
| Ansible alerting + Alertmanager | done |
| G4 Proxmox VE 9.x | done |
| Terraform — 3 k3s VMs provisioned | done |
| Ansible — k3s cluster installed | done |
| MetalLB — IP pool 192.168.1.40-49 | done |
| Traefik — ingress at 192.168.1.40 | done |
| ArgoCD — GitOps at 192.168.1.41 | done |
| kube-state-metrics via Helm | done |
| node-exporter on all k3s nodes | done |
| Promtail DaemonSet shipping logs to Loki | done |
| 7 Prometheus alert rules | done |
| Alertmanager Discord notifications | done |
| PBS monthly backup schedule + restore tested | done |
| DR runbook with RTO/RPO documented | done |
| INC-001 postmortem — ArgoCD crash loop | done |
| INC-002 simulation — CrashLoopBackOff | done |
| INC-003 simulation — disk fill | done |
| cert-manager + TLS | pending |
| App-of-apps ArgoCD pattern | pending |
| Factorio StatefulSet | pending |
| CI/CD pipeline | pending |
| Sealed Secrets | pending |

---

## Portfolio Projects

### Project 1 — GitOps Platform
**Stack:** Kubernetes · ArgoCD · Helm · Git
**Status:** In progress — ArgoCD running, metallb-config synced, app-of-apps pattern pending
**Skills demonstrated:** GitOps, Kubernetes, declarative infrastructure, drift detection

### Project 2 — Observability Stack
**Stack:** Prometheus · Grafana · Loki · Alertmanager · node-exporter · Promtail
**Status:** Complete — 6 targets scraped, 7 alert rules, Discord notifications, logs flowing
**Skills demonstrated:** SRE observability, metrics, logging, alerting, dashboard design

### Project 3 — Incident Simulation Lab
**Stack:** kubectl chaos · Prometheus alerts · Alertmanager · Postmortems
**Status:** In progress — 3 postmortems written (1 real, 2 simulated), NodeDown pending
**Skills demonstrated:** SRE incident response, alert validation, blameless postmortems

### Project 4 — Backup and Disaster Recovery
**Stack:** Proxmox Backup Server · monthly backup schedule · restore drill
**Status:** Complete — monthly backups scheduled, manually tested, DR runbook written
**Skills demonstrated:** DR planning, RTO/RPO documentation, operational discipline

### Project 5 — Real Workload Operations
**Stack:** Factorio · Kubernetes StatefulSet · PVC · SLOs · monitoring
**Status:** Planned — pending G4 RAM upgrade for comfortable headroom
**Skills demonstrated:** Stateful workload operations, SLO definition, end-to-end service management

### Project 6 — Security and Identity
**Stack:** cert-manager · Sealed Secrets · Network Policies · Keycloak
**Status:** Planned
**Skills demonstrated:** TLS everywhere, secrets management, zero-trust networking, SSO

---

## Incident Postmortems

| ID | Type | Summary | Status |
|---|---|---|---|
| INC-001 | Real | ArgoCD crash loop — 34hr detection gap, API server contention | Partially resolved |
| INC-002 | Simulation | CrashLoopBackOff alert validation — full pipeline confirmed | Resolved |
| INC-003 | Simulation | Disk fill — DiskSpaceLow alert fired and resolved | Resolved |

---

## Observability Details

**Prometheus scrape targets:**
- prometheus (self) — localhost:9090
- node-nuc5 — 192.168.1.20:9100
- node-k3s-cp — 192.168.1.30:9100
- node-k3s-w1 — 192.168.1.31:9100
- node-k3s-w2 — 192.168.1.32:9100
- kube-state-metrics — 192.168.1.30:30080

**Alert rules:**
- NodeDown — node exporter unreachable for 2 minutes
- HighMemoryUsage — node memory above 85% for 5 minutes
- HighCPUUsage — node CPU above 80% for 5 minutes
- DiskSpaceLow — filesystem above 80% for 5 minutes
- PodCrashLooping — pod restart rate above 0 over 15 minutes
- PodNotReady — pod not ready for 5 minutes
- NodeMemoryPressure — Kubernetes reporting memory pressure

**Alert routing:** Prometheus → Alertmanager → Discord webhook → #alerts channel

---

## DR Summary

| Scenario | RTO | Method |
|---|---|---|
| Single VM failure | 10-15 min | Restore from PBS backup |
| Full G4 failure | 20-30 min | Restore all VMs from PBS |
| Full rebuild from code | 15 min | terraform apply + ansible k3s.yml |

Full runbook in docs/runbooks/disaster-recovery.md

---

## Tech Stack

| Category | Tool | Version |
|---|---|---|
| Hypervisor | Proxmox VE | 9.x (Debian 13 Trixie) |
| Containers (edge) | LXC | Debian 12 Bookworm |
| Kubernetes | k3s | v1.36.2 |
| IaC | Terraform | >= 1.6 |
| Configuration | Ansible | 2.19.x |
| GitOps | ArgoCD | stable |
| Ingress | Traefik | latest |
| Load Balancing | MetalLB | v0.14.9 |
| Metrics | Prometheus | 2.53.0 |
| Visualization | Grafana | latest |
| Logs | Loki | 3.1.0 |
| Log shipping | Promtail | via Helm |
| Alerting | Alertmanager | 0.27.0 |
| Notifications | Discord webhook | via Alertmanager |
| Backups | Proxmox Backup Server | latest |
| VPN | Tailscale | latest |
| DNS | Pi-hole | latest |
| Uptime | Uptime Kuma | latest |

---

## Repo Structure

```
homelab/
├── infra/
│   ├── terraform/
│   │   └── k8s-vms/            # VM declarations for k3s nodes
│   └── ansible/
│       ├── inventory/
│       │   └── hosts.yml       # All 9 hosts with groups and vars
│       └── playbooks/
│           ├── lxc-baseline.yml      # Edge LXC hardening
│           ├── observability.yml     # Prometheus, Grafana, Loki
│           ├── alerting.yml          # Prometheus alert rules
│           ├── alertmanager.yml      # Alertmanager + Discord
│           ├── node-exporter.yml     # node-exporter on k3s nodes
│           └── k3s.yml               # k3s cluster install
├── k8s/
│   ├── platform/
│   │   ├── argocd/             # ArgoCD install + app-of-apps
│   │   ├── metallb/            # MetalLB IP pool config
│   │   └── traefik/            # Ingress controller values
│   ├── monitoring/
│   │   └── promtail/           # Promtail Helm values
│   └── apps/                   # User-facing applications
├── docs/
│   ├── architecture/
│   │   └── ADR-001-k3s-distribution.md
│   ├── runbooks/
│   │   └── disaster-recovery.md
│   └── postmortems/
│       ├── TEMPLATE.md
│       ├── INC-001-argocd-crashloop.md
│       ├── INC-002-crashloop-simulation.md
│       └── INC-003-disk-fill-simulation.md
└── scripts/
    ├── bootstrap-thinkpad.sh   # One-time ThinkPad tooling install
    └── bootstrap-lxc-ssh.sh   # One-time SSH bootstrap for LXC containers
```

---

## NUC5 Bootstrap Guide

See full guide in the previous README section. Quick reference:

**Key gotchas:**
- Gateway is 192.168.1.254 not 192.168.1.1
- Proxmox VE 9 uses .sources repo format not .list
- LXC containers need SSH bootstrapped before Ansible can manage them
- ansible-core >= 2.18 required for Python 3.13 compatibility on PVE 9 hosts
- PBS enterprise repo ships with both .list and .sources files — blank both

**Bootstrap order:**
1. Install Proxmox on NUC5 and G4
2. Run scripts/bootstrap-thinkpad.sh on ThinkPad
3. Run scripts/bootstrap-lxc-ssh.sh on NUC5 for each container
4. Copy SSH keys: ssh-copy-id for all hosts
5. Run ansible-playbook lxc-baseline.yml
6. Run terraform apply for k3s VMs
7. Run ansible-playbook k3s.yml
8. Bootstrap ArgoCD

---

## Running This Yourself

**Requirements:** Python 3.11+, ansible-core >= 2.18, Terraform >= 1.6, kubectl, Helm 3.x

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# 2. Bootstrap ThinkPad
chmod +x scripts/bootstrap-thinkpad.sh
./scripts/bootstrap-thinkpad.sh

# 3. Bootstrap SSH on LXC containers (one-time)
scp scripts/bootstrap-lxc-ssh.sh root@192.168.1.20:/root/
ssh root@192.168.1.20 'chmod +x bootstrap-lxc-ssh.sh && ./bootstrap-lxc-ssh.sh'

# 4. Copy SSH keys to all hosts
for ip in 192.168.1.20 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24 \
          192.168.1.25 192.168.1.26 192.168.1.27; do
  ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@$ip
done

# 5. Run Ansible baseline
~/ansible-venv/bin/ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/lxc-baseline.yml

# 6. Provision k3s VMs
cd infra/terraform/k8s-vms
terraform init && terraform apply

# 7. Install k3s
cd ~/homelab
~/ansible-venv/bin/ansible-playbook \
  -i infra/ansible/inventory/hosts.yml \
  infra/ansible/playbooks/k3s.yml

# 8. Bootstrap ArgoCD
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Full documentation in docs/architecture/ and docs/runbooks/