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
       │  Proxmox VE       │ │  Proxmox VE         │
       │  ├─ k3s control   │ │  ├─ Pi-hole (DNS)   │
       │  ├─ k3s worker-1  │ │  ├─ Tailscale (VPN) │
       │  └─ k3s worker-2  │ │  ├─ PBS (Backups)   │
       │                   │ │  └─ Uptime Kuma      │
       │  i5-8500T 6c      │ │                     │
       │  32GB DDR4        │ │  i5-5250U 2c        │
       │  256GB NVMe       │ │  16GB DDR3           │
       └───────────────────┘ └────────────────────┘
```

**IP Scheme**

| Host | IP | Role |
|---|---|---|
| Gateway | 192.168.1.1 | ISP router |
| HP EliteDesk G4 | 192.168.1.10 | Compute / Proxmox |
| Intel NUC5 | 192.168.1.20 | Edge services |
| k3s control-plane VM | 192.168.1.30 | Kubernetes control |
| k3s worker-1 VM | 192.168.1.31 | Kubernetes worker |
| k3s worker-2 VM | 192.168.1.32 | Kubernetes worker |
| MetalLB pool | 192.168.1.40–49 | LoadBalancer IPs |

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
| Hypervisor | Proxmox VE 8.x |
| Containers | Kubernetes (k3s) |
| IaC | Terraform (Proxmox provider) |
| Configuration | Ansible |
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
│       ├── playbooks/      # Ordered playbooks (baseline, k3s, etc.)
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
└── diagrams/               # Architecture diagrams
```

---

## Build Order

1. **Phase 0** — Control plane tooling + NUC5 Proxmox + Ansible baseline
2. **Phase 1** — G4 Proxmox + Terraform VM provisioning + k3s cluster
3. **Phase 2** — MetalLB + Traefik + cert-manager + ArgoCD
4. **Phase 3** — Observability stack (Prometheus + Grafana + Loki)
5. **Phase 4** — SRE layer (SLOs, alerting, incident simulation, DR drills)
6. **Phase 5** — Security hardening + secrets management

---

## Status

| Component | Status |
|---|---|
| NUC5 Proxmox | 🔲 Planned |
| G4 Proxmox | 🔲 Planned |
| Ansible baseline | 🔲 Planned |
| Terraform VM provisioning | 🔲 Planned |
| k3s cluster | 🔲 Planned |
| MetalLB | 🔲 Planned |
| Traefik | 🔲 Planned |
| ArgoCD | 🔲 Planned |
| Prometheus + Grafana | 🔲 Planned |
| Loki | 🔲 Planned |
| PBS backups | 🔲 Planned |

---

## Running This Yourself

Prerequisites: Proxmox VE 8.x, Terraform >= 1.6, Ansible >= 2.15, kubectl, Helm 3.x

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/homelab.git
cd homelab

# 2. Provision VMs via Terraform
cd infra/terraform/k8s-vms
terraform init && terraform apply

# 3. Run Ansible baseline
cd infra/ansible
ansible-playbook -i inventory/hosts.yml playbooks/baseline.yml

# 4. Install k3s
ansible-playbook -i inventory/hosts.yml playbooks/k3s.yml

# 5. Bootstrap ArgoCD
kubectl apply -k k8s/platform/argocd/
```

Full setup documentation is in [`docs/architecture/`](docs/architecture/).
