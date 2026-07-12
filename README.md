# Homelab — Production-Grade Infrastructure Portfolio

A self-hosted, production-aligned platform built to demonstrate real-world DevOps, Cloud Engineering, and SRE skills. Every layer of this infrastructure — from bare metal provisioning to application deployment — is managed as code.

---

## Architecture

```
ThinkPad P51 (Control Plane)
Terraform · Ansible 2.19 · kubectl · Helm · Git · Tailscale
         |                          |
HP EliteDesk G4 (Compute)     Intel NUC5i5RYH (Edge)
Proxmox VE 9.x                Proxmox VE 9.x
WiFi: wlp0s20f3               WiFi: wlp2s0
                               NATs LXC containers
k3s-cp-01  192.168.1.30       Pi-hole      192.168.1.21
k3s-w-01   192.168.1.31       Tailscale    192.168.1.22
k3s-w-02   192.168.1.32       Uptime Kuma  192.168.1.23
                               PBS          192.168.1.24
i5-8500T 6c 16GB 256GB NVMe   Prometheus   192.168.1.25
                               Grafana      192.168.1.26
                               Loki         192.168.1.27
```

---

## Network Map

### Physical Hosts

| Host | IP | WiFi Interface | Role |
|---|---|---|---|
| ThinkPad P51 | 192.168.1.231 (DHCP) | wlp4s0 | Control plane |
| HP EliteDesk G4 | 192.168.1.10 | wlp0s20f3 | Compute node |
| Intel NUC5 | 192.168.1.20 | wlp2s0 | Edge node |
| ISP Router | 192.168.1.254 | — | Default gateway |

### NUC5 LXC Containers

| Service | IP | Port | URL | CT ID |
|---|---|---|---|---|
| Pi-hole | 192.168.1.21 | 80 | http://192.168.1.21/admin | 100 |
| Tailscale | 192.168.1.22 | — | — | 101 |
| Uptime Kuma | 192.168.1.23 | 3001 | http://192.168.1.23:3001 | 102 |
| PBS | 192.168.1.24 | 8007 | https://192.168.1.24:8007 | 103 |
| Prometheus | 192.168.1.25 | 9090 | http://192.168.1.25:9090 | 104 |
| Alertmanager | 192.168.1.25 | 9093 | http://192.168.1.25:9093 | 104 |
| Grafana | 192.168.1.26 | 3000 | https://grafana.home.lab | 105 |
| Loki | 192.168.1.27 | 3100 | http://192.168.1.27:3100/ready | 106 |

### G4 k3s VMs

| Host | IP | Role | VM ID |
|---|---|---|---|
| k3s-cp-01 | 192.168.1.30 | Control plane | 300 |
| k3s-w-01 | 192.168.1.31 | Worker | 301 |
| k3s-w-02 | 192.168.1.32 | Worker | 302 |

### Kubernetes Services — MetalLB Pool 192.168.1.40-49

| Service | IP | Port | URL |
|---|---|---|---|
| Traefik ingress | 192.168.1.40 | 80/443 | — |
| ArgoCD | 192.168.1.41 | 443 | https://argocd.home.lab |
| Factorio NucFactory | 192.168.1.40 | 34197/UDP | — |

### Internal DNS — Pi-hole

| Hostname | Resolves To | Service |
|---|---|---|
| argocd.home.lab | 192.168.1.40 | ArgoCD via Traefik |
| grafana.home.lab | 192.168.1.40 | Grafana via Traefik |

### Tailscale

| Device | Tailscale IP | Notes |
|---|---|---|
| tailscale LXC | 100.76.37.3 | Subnet router — advertises 192.168.1.0/24 |
| ThinkPad | 100.95.82.46 | Control plane |

---

## Web UIs

| Service | URL | Notes |
|---|---|---|
| Proxmox NUC5 | https://192.168.1.20:8006 | root / PAM |
| Proxmox G4 | https://192.168.1.10:8006 | root / PAM |
| Pi-hole | http://192.168.1.21/admin | — |
| Uptime Kuma | http://192.168.1.23:3001 | — |
| PBS | https://192.168.1.24:8007 | root / PAM |
| Prometheus | http://192.168.1.25:9090 | no auth |
| Alertmanager | http://192.168.1.25:9093 | no auth |
| Grafana | https://grafana.home.lab | admin |
| ArgoCD | https://argocd.home.lab | admin |

---

## Status

| Component | Status |
|---|---|
| ThinkPad control plane | done |
| NUC5 Proxmox VE 9.x + WiFi uplink | done |
| G4 Proxmox VE 9.x + WiFi uplink | done |
| 7 LXC edge services — Ansible managed | done |
| Ansible — 9 hosts, 6 playbooks | done |
| Terraform — 3 k3s VMs | done |
| k3s v1.36.2 — 3 node cluster | done |
| QEMU guest agent on all k3s VMs | done |
| MetalLB + Traefik | done |
| ArgoCD — app-of-apps, 6 apps Synced | done |
| cert-manager — CA + TLS | done |
| Factorio NucFactory + Space Age DLC | done |
| Tailscale subnet routing | done |
| Prometheus + 7 alert rules | done |
| Grafana + dashboards | done |
| Loki + Promtail | done |
| Alertmanager + Discord | done |
| PBS monthly backups + restore tested | done |
| Network watchdog G4 + NUC5 | done |
| NUC5 g4-monitor | done |
| iptables-persistent on both nodes | done |
| QEMU guest agent on k3s VMs | done |
| INC-001 through INC-006 postmortems | done |
| NodeDown simulation INC-007 | pending |
| Dashboards as code | pending |
| SLO dashboard + error budget | pending |
| CI/CD pipeline | pending |
| Sealed Secrets | pending |
| G4 RAM upgrade 32GB | pending |
| Valheim server | pending |
| Keycloak SSO | pending |

---

## ArgoCD Application Tree

```
app-of-apps (watches k8s/platform/argocd/apps/)
├── cert-manager
├── cert-manager-resources
├── factorio
├── metallb-config
└── traefik
```

Adding a service = manifests folder + Application yaml in k8s/platform/argocd/apps/ + git push.

---

## Portfolio Projects

### Project 1 — GitOps Platform
Stack: Kubernetes, ArgoCD, Helm, app-of-apps
Status: Complete — 6 apps Synced and Healthy
Story: Every deployment is a Git commit. No manual kubectl in production.

### Project 2 — Observability Stack
Stack: Prometheus, Grafana, Loki, Alertmanager, Promtail
Status: Complete — 6 targets, 7 rules, Discord alerts, logs flowing, TLS
Story: Monitoring runs on a separate physical machine from the cluster it monitors.

### Project 3 — Incident Simulation Lab
Stack: Chaos, alerts, Discord, postmortems
Status: 6 postmortems — 4 real incidents, 2 simulations
Story: I break things deliberately and document what happens including corrected diagnoses.

### Project 4 — Backup and DR
Stack: PBS, watchdogs, QEMU agent, runbook
Status: Complete — automated recovery, RTO documented
Story: Network watchdogs auto-recover both servers. QEMU agent enables VM recovery without physical access.

### Project 5 — Real Workload Operations
Stack: Factorio Space Age, StatefulSet, PVC, ArgoCD, Tailscale
Status: Complete — NucFactory running, GitOps managed
Story: Real user-facing stateful service. Config in Git, world persists on PVC.

### Project 6 — Security and Identity
Stack: cert-manager, TLS, Pi-hole DNS
Status: Partial — TLS done, Sealed Secrets + Keycloak pending

---

## Incident Postmortems

| ID | Type | Summary | RTO |
|---|---|---|---|
| INC-001 | Real | ArgoCD crash loop, 34hr detection gap | 22 min |
| INC-002 | Simulation | CrashLoopBackOff alert validation | 10 min |
| INC-003 | Simulation | Disk fill DiskSpaceLow validation | 8 min |
| INC-004 | Real | G4 outage — TP-Link ARP bridge failure | 45 min |
| INC-005 | Real | Recurring nightly outage at 2am | 60 min |
| INC-006 | Real | G4 ethernet NIC hardware failure | 120 min |

---

## Network Resilience

Both servers connect via built-in WiFi directly to the router. No ethernet bridge dependency.

NUC5: wlp2s0, NATs LXC containers (gw=192.168.1.20), iptables-persistent
G4: wlp0s20f3, VMs use vmbr0 bridge, nic0 (e1000e) known faulty — watchdog resets it

Watchdogs (systemd timer, every 2 minutes):
- G4: resets nic0 and vmbr0 if gateway unreachable
- NUC5: reconnects WiFi if gateway unreachable
- NUC5 g4-monitor: pings G4, attempts SSH recovery, Discord alert on failure

---

## Observability

Scrape targets: prometheus, node-nuc5, node-k3s-cp, node-k3s-w1, node-k3s-w2, kube-state-metrics

Alert rules: NodeDown, HighMemoryUsage, HighCPUUsage, DiskSpaceLow, PodCrashLooping, PodNotReady, NodeMemoryPressure

Routing: Prometheus -> Alertmanager -> Discord #alerts

---

## DR Summary

| Scenario | RTO | Method |
|---|---|---|
| Network watchdog recovery | 2-6 min | Automatic |
| Single VM restore | 10-15 min | PBS backup |
| Full G4 restore | 20-30 min | PBS backup |
| Full rebuild from code | 15 min | terraform + ansible + ArgoCD |

---

## Known Issues

| Issue | Root Cause | Fix |
|---|---|---|
| applicationset-controller CrashLoopBackOff | API server contention on 16GB RAM | Upgrade G4 to 32GB |
| svclb-argocd-server Pending | k3s ServiceLB conflicts with MetalLB | No functional impact |
| G4 nic0 e1000e errors | Aging NIC hardware | Watchdog auto-resets |

---

## Quick Reference

### SSH

    ssh root@192.168.1.20        # NUC5
    ssh root@192.168.1.10        # G4
    ssh ubuntu@192.168.1.30      # k3s-cp-01
    ssh ubuntu@192.168.1.31      # k3s-w-01
    ssh ubuntu@192.168.1.32      # k3s-w-02
    ssh root@192.168.1.21        # Pi-hole (CT 100)
    ssh root@192.168.1.22        # Tailscale (CT 101)
    ssh root@192.168.1.23        # Uptime Kuma (CT 102)
    ssh root@192.168.1.24        # PBS (CT 103)
    ssh root@192.168.1.25        # Prometheus (CT 104)
    ssh root@192.168.1.26        # Grafana (CT 105)
    ssh root@192.168.1.27        # Loki (CT 106)

### LXC Management (on NUC5)

    pct list
    pct exec 100 -- bash         # Pi-hole
    pct exec 104 -- bash         # Prometheus
    pct start/stop <id>

### Kubernetes

    kubectl get nodes
    kubectl get pods -A
    kubectl get applications -n argocd
    kubectl logs -n factorio factorio-0
    kubectl annotate application app-of-apps -n argocd argocd.argoproj.io/refresh=hard --overwrite

### Ansible

    cd ~/workspace/homelab
    ~/ansible-venv/bin/ansible all -i infra/ansible/inventory/hosts.yml -m ping
    ~/ansible-venv/bin/ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/PLAYBOOK.yml

    # Alertmanager requires webhook env var
    export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
    ~/ansible-venv/bin/ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/alertmanager.yml

### Terraform

    cd infra/terraform/k8s-vms
    terraform init && terraform apply

### Watchdog Logs

    ssh root@192.168.1.10 'cat /var/log/network-watchdog.log'
    ssh root@192.168.1.20 'cat /var/log/network-watchdog.log'
    ssh root@192.168.1.20 'cat /var/log/g4-monitor.log'

### Prometheus Queries

    # CPU usage %
    100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

    # Memory usage %
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

    # Disk usage %
    (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100

### Loki Queries

    {namespace="argocd"}
    {namespace="factorio"}
    {namespace="monitoring"}
    {namespace="argocd"} |= "error"

---

## Rebuild From Scratch

    git clone https://github.com/Tim-McCann/homelab.git && cd homelab
    chmod +x scripts/bootstrap-thinkpad.sh && ./scripts/bootstrap-thinkpad.sh
    scp scripts/bootstrap-lxc-ssh.sh root@192.168.1.20:/root/
    ssh root@192.168.1.20 'chmod +x bootstrap-lxc-ssh.sh && ./bootstrap-lxc-ssh.sh'
    for ip in 192.168.1.20 192.168.1.21 192.168.1.22 192.168.1.23 192.168.1.24 192.168.1.25 192.168.1.26 192.168.1.27; do ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@$ip; done
    ~/ansible-venv/bin/ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/lxc-baseline.yml
    cd infra/terraform/k8s-vms && terraform init && terraform apply
    cd ~/homelab && ~/ansible-venv/bin/ansible-playbook -i infra/ansible/inventory/hosts.yml infra/ansible/playbooks/k3s.yml
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl apply -f k8s/platform/argocd/app-of-apps.yaml
