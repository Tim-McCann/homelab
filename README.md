# Homelab — Production-Grade Infrastructure Portfolio

A self-hosted, production-aligned platform built. Every layer is managed as code — from bare metal provisioning to application deployment.

---

## Architecture Overview

```
                    ThinkPad P51 (Control Plane)
                 Terraform · Ansible · kubectl · Helm · Git
                         |                    |
            ┌────────────┘                    └────────────┐
            │                                              │
  HP EliteDesk G4 Mini                        Intel NUC5i5RYH
  Compute Node                                Edge Node
  192.168.1.10                                192.168.1.20
  Proxmox VE 9.x                              Proxmox VE 9.x
  WiFi: wlp0s20f3                             WiFi: wlp2s0
  Bridge: vmbr0 (nic0 - failing)              NATs LXC via iptables
  i5-8500T 6c 16GB DDR4                       i5-5250U 2c 16GB DDR3
            │                                              │
     ┌──────┴──────┐                          ┌───────────┴──────────┐
     │  k3s VMs    │                          │   LXC Containers     │
     │             │                          │                      │
     │ k3s-cp-01   │ 192.168.1.30            │ Pi-hole    .21       │
     │ k3s-w-01    │ 192.168.1.31            │ Tailscale  .22       │
     │ k3s-w-02    │ 192.168.1.32            │ Uptime Kuma.23       │
     └─────────────┘                          │ PBS        .24       │
                                              │ Prometheus .25       │
     Kubernetes Services                      │ Grafana    .26       │
     MetalLB Pool: .40-.49                    │ Loki       .27       │
                                              └──────────────────────┘
     Traefik    192.168.1.40
     ArgoCD     192.168.1.41  https://argocd.home.lab
     Factorio   192.168.1.40  :34197/UDP
```

---

## Network Reference

### Physical Hosts

| Host | IP | Interface | Gateway |
|---|---|---|---|
| ThinkPad P51 | 192.168.1.231 (DHCP) | wlp4s0 | 192.168.1.254 |
| HP EliteDesk G4 | 192.168.1.10 | wlp0s20f3 (WiFi) | 192.168.1.254 |
| Intel NUC5 | 192.168.1.20 | wlp2s0 (WiFi) | 192.168.1.254 |
| ISP Router | 192.168.1.254 | — | — |

### NUC5 LXC Containers (gateway: 192.168.1.20)

| Service | IP | Port | URL | CT |
|---|---|---|---|---|
| Pi-hole | 192.168.1.21 | 80 | http://192.168.1.21/admin | 100 |
| Tailscale | 192.168.1.22 | — | — | 101 |
| Uptime Kuma | 192.168.1.23 | 3001 | http://192.168.1.23:3001 | 102 |
| PBS | 192.168.1.24 | 8007 | https://192.168.1.24:8007 | 103 |
| Prometheus | 192.168.1.25 | 9090 | http://192.168.1.25:9090 | 104 |
| Alertmanager | 192.168.1.25 | 9093 | http://192.168.1.25:9093 | 104 |
| Grafana | 192.168.1.26 | 3000 | https://grafana.home.lab | 105 |
| Loki | 192.168.1.27 | 3100 | http://192.168.1.27:3100/ready | 106 |

### G4 k3s VMs (gateway: 192.168.1.254 via vmbr0)

| Host | IP | Role | VM |
|---|---|---|---|
| k3s-cp-01 | 192.168.1.30 | Control plane | 300 |
| k3s-w-01 | 192.168.1.31 | Worker | 301 |
| k3s-w-02 | 192.168.1.32 | Worker | 302 |
| ubuntu template | stopped | Cloud-init base | 9000 |

### Kubernetes Services (MetalLB pool: 192.168.1.40-49)

| Service | IP | Port | URL |
|---|---|---|---|
| Traefik | 192.168.1.40 | 80/443 | ingress controller |
| ArgoCD | 192.168.1.41 | 443 | https://argocd.home.lab |
| Factorio | 192.168.1.40 | 34197/UDP | NucFactory game server |

### DNS Records (Pi-hole local DNS)

| Hostname | IP | Service |
|---|---|---|
| argocd.home.lab | 192.168.1.41 | ArgoCD via Traefik |
| grafana.home.lab | 192.168.1.41 | Grafana via Traefik |

### Tailscale

| Device | Tailscale IP | Role |
|---|---|---|
| tailscale LXC | 100.76.37.3 | Subnet router — advertises 192.168.1.0/24 |
| ThinkPad | 100.95.82.46 | Control plane |

---

## Web UIs Quick Reference

| Service | URL | Notes |
|---|---|---|
| Proxmox NUC5 | https://192.168.1.20:8006 | root/PAM |
| Proxmox G4 | https://192.168.1.10:8006 | root/PAM |
| Pi-hole | http://192.168.1.21/admin | — |
| Uptime Kuma | http://192.168.1.23:3001 | — |
| PBS | https://192.168.1.24:8007 | root/PAM |
| Prometheus | http://192.168.1.25:9090 | no auth |
| Alertmanager | http://192.168.1.25:9093 | no auth |
| Grafana | https://grafana.home.lab | admin |
| ArgoCD | https://argocd.home.lab | admin |

ArgoCD password reset:

    kubectl -n argocd get secret argocd-initial-admin-secret \
      -o jsonpath="{.data.password}" | base64 -d && echo

---

## ArgoCD Application Tree

```
app-of-apps (watches k8s/platform/argocd/apps/)
├── cert-manager          Helm — jetstack
├── cert-manager-resources  ClusterIssuers, Ingresses
├── factorio              StatefulSet, PVC, ConfigMap
├── metallb-config        IPAddressPool, L2Advertisement
├── network-policies      Default deny + allow rules
├── sealed-secrets        Helm — bitnami
└── traefik               Helm values
```

Adding a new service = create manifests + add Application yaml to
k8s/platform/argocd/apps/ + git push + kubectl apply (until RAM upgrade fixes
applicationset-controller).

---

## Startup Guide — After Everything Is Off

If you've rebooted both servers or they've been off, follow this order:

### Step 1 — Verify both servers are up

    ping -c 2 192.168.1.10   # G4
    ping -c 2 192.168.1.20   # NUC5

If either is unreachable see the Troubleshooting section below.

### Step 2 — Verify NUC5 containers

    ssh root@192.168.1.20
    pct list

All 7 containers should show running. If any are stopped:

    pct start 100   # Pi-hole
    pct start 101   # Tailscale
    pct start 102   # Uptime Kuma
    pct start 103   # PBS
    pct start 104   # Prometheus
    pct start 105   # Grafana
    pct start 106   # Loki

### Step 3 — Verify k3s cluster

    kubectl get nodes
    kubectl get applications -n argocd

All 3 nodes should be Ready. All apps should be Synced and Healthy.
If apps show Unknown, force a refresh:

    kubectl annotate application app-of-apps -n argocd \
      argocd.argoproj.io/refresh=hard --overwrite

### Step 4 — Verify Factorio

    kubectl get pods -n factorio
    kubectl get svc -n factorio

Factorio should be Running at 192.168.1.40:34197.

### Step 5 — Verify monitoring

Open http://192.168.1.25:9090/targets — all 6 targets should be green.
Open https://grafana.home.lab — dashboards should show data.

---

## Troubleshooting

### G4 unreachable

Check if WiFi is up:

    # Physical access to G4 console
    ip link show wlp0s20f3
    wpa_cli status

If wpa_state is not COMPLETED:

    wpa_supplicant -B -i wlp0s20f3 -c /etc/wpa_supplicant/wpa_supplicant.conf
    dhclient wlp0s20f3

If Hardware Unit Hang errors in dmesg (e1000e NIC failure):

    # Watchdog auto-detects and reboots — check Discord for alert
    # Or manually reboot the G4
    reboot

### k3s VMs unreachable from outside but G4 is up

The bridge may have lost its tap interfaces. Restart VMs:

    ssh root@192.168.1.10
    for vm in 300 301 302; do qm stop $vm; done
    sleep 5
    for vm in 300 301 302; do qm start $vm; done
    sleep 60
    ping -c 2 192.168.1.30

### NUC5 containers have no internet

Containers NAT through NUC5 host WiFi. Check NAT rules:

    ssh root@192.168.1.20
    iptables -t nat -L POSTROUTING | grep MASQUERADE
    pct exec 100 -- ping -c 2 8.8.8.8

If no internet, restore NAT:

    iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o wlp2s0 -j MASQUERADE
    iptables -A FORWARD -i vmbr0 -o wlp2s0 -j ACCEPT
    iptables -A FORWARD -i wlp2s0 -o vmbr0 -m state --state RELATED,ESTABLISHED -j ACCEPT
    netfilter-persistent save

### ArgoCD apps showing Unknown

Force refresh:

    kubectl annotate application app-of-apps -n argocd \
      argocd.argoproj.io/refresh=hard --overwrite

If CoreDNS can't resolve github.com restart it:

    kubectl rollout restart deployment/coredns -n kube-system

### SSH host key changed (after VM restart)

    ssh-keygen -f "/home/tim/.ssh/known_hosts" -R "192.168.1.30"
    ssh-keygen -f "/home/tim/.ssh/known_hosts" -R "192.168.1.31"
    ssh-keygen -f "/home/tim/.ssh/known_hosts" -R "192.168.1.32"

### Grafana not reachable via hostname

Check Pi-hole DNS records point to 192.168.1.41:

    nslookup grafana.home.lab 192.168.1.21

If wrong, update in Pi-hole admin → Local DNS → DNS Records.
Flush ThinkPad DNS cache:

    sudo resolvectl flush-caches

---

## Common Commands

### SSH

    ssh root@192.168.1.10        # G4 Proxmox
    ssh root@192.168.1.20        # NUC5 Proxmox
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
    pct start/stop <id>
    pct exec <id> -- bash
    pct exec 100 -- ping -c 2 8.8.8.8    # test container internet

### Proxmox VM Management (on G4)

    qm list
    qm start/stop <id>
    qm terminal <id>                      # console into VM
    qm guest exec <id> -- hostname        # exec via QEMU agent

### Kubernetes

    kubectl get nodes
    kubectl get pods -A
    kubectl get pods -A | grep -v Running | grep -v Completed
    kubectl get applications -n argocd
    kubectl top nodes
    kubectl top pods -A

    # Per namespace
    kubectl get pods -n argocd
    kubectl get pods -n factorio
    kubectl get pods -n monitoring
    kubectl get pods -n cert-manager

    # Logs
    kubectl logs -n factorio factorio-0
    kubectl logs -n factorio factorio-0 -f
    kubectl logs -n argocd deployment/argocd-server --tail=20

    # ArgoCD force refresh
    kubectl annotate application app-of-apps -n argocd \
      argocd.argoproj.io/refresh=hard --overwrite

    # Factorio
    kubectl exec -n factorio factorio-0 -- ls /factorio/saves/
    kubectl rollout restart statefulset/factorio -n factorio

### Ansible

    cd ~/workspace/homelab

    # Test all hosts
    ~/ansible-venv/bin/ansible all \
      -i infra/ansible/inventory/hosts.yml -m ping

    # Run playbooks
    ~/ansible-venv/bin/ansible-playbook \
      -i infra/ansible/inventory/hosts.yml \
      infra/ansible/playbooks/lxc-baseline.yml

    # Alertmanager needs Discord webhook
    export DISCORD_WEBHOOK="https://discord.com/api/webhooks/..."
    ~/ansible-venv/bin/ansible-playbook \
      -i infra/ansible/inventory/hosts.yml \
      infra/ansible/playbooks/alertmanager.yml

### Terraform

    cd infra/terraform/k8s-vms
    terraform init
    terraform plan
    terraform apply
    terraform destroy

### Sealed Secrets

    # Seal a new secret
    kubectl create secret generic my-secret \
      --from-literal=key=value \
      --namespace=default \
      --dry-run=client -o yaml | \
      kubeseal \
      --controller-name=sealed-secrets-controller \
      --controller-namespace=kube-system \
      --format yaml > k8s/platform/sealed-secrets/my-secret.yaml

    # Apply sealed secret
    kubectl apply -f k8s/platform/sealed-secrets/my-secret.yaml

### Watchdog Logs

    ssh root@192.168.1.10 'cat /var/log/network-watchdog.log'
    ssh root@192.168.1.20 'cat /var/log/network-watchdog.log'
    ssh root@192.168.1.20 'cat /var/log/g4-monitor.log'

    # Check timers
    ssh root@192.168.1.10 'systemctl status network-watchdog.timer'
    ssh root@192.168.1.20 'systemctl status g4-monitor.timer'
    ssh root@192.168.1.20 'systemctl status network-watchdog.timer'

---

## Prometheus Queries

    # CPU usage per node
    100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

    # Memory usage per node
    (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

    # Disk usage per node
    (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} /
      node_filesystem_size_bytes{fstype!="tmpfs"})) * 100

    # Pod restart rate
    rate(kube_pod_container_status_restarts_total[15m]) * 60

    # SLO — Factorio availability
    slo:factorio:availability1h
    slo:factorio:availability30d
    slo:factorio:error_budget_remaining30d

    # SLO — cluster nodes ready
    slo:cluster:nodes_ready1h
    slo:cluster:nodes_ready30d

## Loki Queries

    {namespace="argocd"}
    {namespace="factorio"}
    {namespace="kube-system"}
    {namespace="monitoring"}
    {namespace="argocd"} |= "error"
    {namespace="factorio"} |= "ERROR"

---

## Alert Rules

| Alert | Condition | Window | Severity |
|---|---|---|---|
| NodeDown | node-exporter unreachable | 2 min | critical |
| HighMemoryUsage | above 85% | 5 min | warning |
| HighCPUUsage | above 80% | 5 min | warning |
| DiskSpaceLow | above 80% full | 5 min | warning |
| PodCrashLooping | restart rate above 0 | 15 min | warning |
| PodNotReady | not ready | 5 min | warning |
| NodeMemoryPressure | k8s memory pressure | 2 min | critical |

All alerts route: Prometheus → Alertmanager → Discord #alerts

---

## DR Reference

| Scenario | RTO | Method |
|---|---|---|
| Watchdog auto-recovery | 2-6 min | Automatic |
| Single VM restore | 10-15 min | PBS backup |
| Full G4 restore | 20-30 min | PBS backup |
| Full rebuild from code | 15 min | terraform + ansible + ArgoCD |

Full runbook: docs/runbooks/disaster-recovery.md

---

## Incident Postmortems

| ID | Type | Summary | RTO |
|---|---|---|---|
| INC-001 | Real | ArgoCD crash loop, 34hr detection gap | 22 min |
| INC-002 | Simulation | CrashLoopBackOff validation | 10 min |
| INC-003 | Simulation | Disk fill DiskSpaceLow validation | 8 min |
| INC-004 | Real | G4 outage — TP-Link ARP bridge failure | 45 min |
| INC-005 | Real | Recurring nightly outage at 2am | 60 min |
| INC-006 | Real | G4 ethernet NIC hardware failure | 120 min |
| INC-007 | Simulation | NodeDown alert validation | 6 min |

---

## Known Issues

| Issue | Root Cause | Fix |
|---|---|---|
| applicationset-controller CrashLoopBackOff | API server contention 16GB RAM | Upgrade G4 to 32GB |
| svclb-argocd-server Pending | k3s ServiceLB conflicts with MetalLB | No impact, ignore |
| G4 nic0 e1000e Hardware Unit Hangs | Aging NIC hardware | Watchdog auto-reboots; buy USB ethernet adapter |
| New ArgoCD apps need manual kubectl apply | applicationset-controller crash | Fixed by RAM upgrade |

---

# Projects

| Project | Stack | Status |
|---|---|---|
| 1 — GitOps Platform | ArgoCD, app-of-apps, 8 apps | Complete |
| 2 — Observability Stack | Prometheus, Grafana, Loki, Alertmanager | Complete |
| 3 — Incident Simulation Lab | 7 postmortems, 4 real + 3 simulated | Complete |
| 4 — Backup and DR | PBS, watchdogs, QEMU agent, runbook | Complete |
| 5 — Real Workload | Factorio Space Age StatefulSet | Complete |
| 6 — Security | TLS, Sealed Secrets, Network Policies | Complete |

Pending (requires RAM upgrade):
- Valheim server
- Keycloak SSO
- Immich photo library
- Multi-environment GitOps (needs custom app)

---

## Tech Stack

| Category | Tool | Version |
|---|---|---|
| Hypervisor | Proxmox VE | 9.x (Debian 13 Trixie) |
| Kubernetes | k3s | v1.36.2 |
| IaC | Terraform + bpg/proxmox | >= 1.6 |
| Configuration | Ansible | 2.19.x |
| GitOps | ArgoCD | 3.4.4 |
| Load Balancing | MetalLB | v0.14.9 |
| Ingress | Traefik | latest |
| TLS | cert-manager | v1.16.0 |
| Secrets | Sealed Secrets | 0.27.3 |
| Metrics | Prometheus | 2.53.0 |
| Visualization | Grafana | latest |
| Logs | Loki | 3.1.0 |
| Log shipping | Promtail | via Helm |
| Alerting | Alertmanager | 0.27.0 |
| Backups | PBS | latest |
| VPN | Tailscale | 1.98.4 |
| DNS | Pi-hole | latest |
| Uptime | Uptime Kuma | latest |
| Game server | Factorio Space Age | stable |

---

## Repo Structure

```
homelab/
├── infra/
│   ├── terraform/k8s-vms/          # VM provisioning
│   └── ansible/
│       ├── inventory/hosts.yml     # All 9 hosts
│       └── playbooks/              # 6 playbooks
├── k8s/
│   ├── platform/
│   │   ├── argocd/
│   │   │   ├── app-of-apps.yaml
│   │   │   └── apps/               # All Application yamls
│   │   ├── cert-manager/           # ClusterIssuers, Ingresses
│   │   ├── metallb/                # IP pool
│   │   ├── network-policies/       # Default deny + allow rules
│   │   ├── sealed-secrets/         # Encrypted secrets
│   │   └── traefik/                # Helm values
│   ├── monitoring/
│   │   ├── grafana/dashboards/     # Dashboard JSONs
│   │   └── promtail/               # Helm values
│   └── apps/
│       └── factorio/               # StatefulSet, PVC, ConfigMap
├── docs/
│   ├── architecture/               # ADRs
│   ├── runbooks/                   # DR runbook
│   └── postmortems/                # INC-001 through INC-007
└── scripts/
    ├── bootstrap-thinkpad.sh
    ├── bootstrap-lxc-ssh.sh
    ├── trust-homelab-ca.sh
    └── watchdog/
        ├── g4-network-watchdog.sh
        ├── nuc5-network-watchdog.sh
        └── g4-monitor.sh
```

---

## Rebuild From Scratch

    git clone https://github.com/Tim-McCann/homelab.git && cd homelab

    # Bootstrap ThinkPad tools
    chmod +x scripts/bootstrap-thinkpad.sh && ./scripts/bootstrap-thinkpad.sh

    # Bootstrap LXC SSH on NUC5
    scp scripts/bootstrap-lxc-ssh.sh root@192.168.1.20:/root/
    ssh root@192.168.1.20 'chmod +x bootstrap-lxc-ssh.sh && ./bootstrap-lxc-ssh.sh'

    # Copy SSH keys to all hosts
    for ip in 192.168.1.20 192.168.1.21 192.168.1.22 192.168.1.23 \
              192.168.1.24 192.168.1.25 192.168.1.26 192.168.1.27; do
      ssh-copy-id -i ~/.ssh/homelab_ed25519.pub root@$ip
    done

    # Configure NUC5 observability
    ~/ansible-venv/bin/ansible-playbook \
      -i infra/ansible/inventory/hosts.yml \
      infra/ansible/playbooks/lxc-baseline.yml

    # Provision k3s VMs
    cd infra/terraform/k8s-vms && terraform init && terraform apply

    # Install k3s
    cd ~/homelab
    ~/ansible-venv/bin/ansible-playbook \
      -i infra/ansible/inventory/hosts.yml \
      infra/ansible/playbooks/k3s.yml

    # Bootstrap ArgoCD
    kubectl apply -n argocd -f \
      https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    kubectl patch svc argocd-server -n argocd \
      -p '{"spec": {"type": "LoadBalancer"}}'
    kubectl apply -f k8s/platform/argocd/app-of-apps.yaml

    # Trust homelab CA in browser
    chmod +x scripts/trust-homelab-ca.sh && ./scripts/trust-homelab-ca.sh