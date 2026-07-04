# Disaster Recovery Runbook

## Overview

This runbook covers recovery procedures for the homelab infrastructure.
Backups are stored on PBS (Proxmox Backup Server) running on the NUC5 at 192.168.1.24.

## Backup Schedule

| Target | Schedule | Storage | Retention |
|---|---|---|---|
| k3s-cp-01 (VM 300) | Monthly | pbs-nuc5/vm-backups | Last 1 |
| k3s-w-01 (VM 301) | Monthly | pbs-nuc5/vm-backups | Last 1 |
| k3s-w-02 (VM 302) | Monthly | pbs-nuc5/vm-backups | Last 1 |

## Recovery Scenarios

### Scenario 1 — Single VM failure

A k3s worker node fails. k3s handles this automatically — workloads are
rescheduled to remaining nodes. No manual intervention required for the
cluster to continue operating.

To restore the failed VM from backup:
1. Go to G4 Proxmox UI at https://192.168.1.10:8006
2. Select the failed VM
3. Restore → select latest backup from pbs-nuc5
4. Start the restored VM
5. k3s agent rejoins the cluster automatically

Estimated RTO: 10-15 minutes

### Scenario 2 — Full G4 failure

The G4 compute node fails completely — all 3 k3s VMs lost.

Recovery steps:
1. Fix or replace the G4 hardware
2. Install Proxmox VE 9.x — follow docs/architecture/ADR-001
3. Add pbs-nuc5 storage: Datacenter → Storage → Add → Proxmox Backup Server
4. Restore all 3 VMs from PBS backup
5. Start VMs in order: k3s-cp-01 first, then workers
6. Verify cluster: kubectl get nodes
7. Verify ArgoCD syncs all apps: kubectl get applications -n argocd

Estimated RTO: 20-30 minutes (excluding hardware replacement)

### Scenario 3 — Reprovisioning from scratch

Complete rebuild from code, no backup needed:

1. Install Proxmox on G4
2. Run Terraform: cd infra/terraform/k8s-vms && terraform apply
3. Run Ansible: ansible-playbook -i inventory/hosts.yml playbooks/k3s.yml
4. Bootstrap ArgoCD: kubectl apply -n argocd -f k8s/platform/argocd/install.yaml
5. Connect repo in ArgoCD UI
6. All apps sync automatically from Git

Estimated RTO: 15-20 minutes

## Verifying Backups

Check backup status in PBS UI:
https://192.168.1.24:8007 → Datastore → vm-backups → Content

Check backup job status in Proxmox:
https://192.168.1.10:8006 → Datacenter → Backup

## RTO/RPO Summary

| Metric | Value |
|---|---|
| RPO (data loss) | Up to 1 month (monthly backup schedule) |
| RTO single VM | 10-15 minutes |
| RTO full G4 failure | 20-30 minutes |
| RTO full rebuild from code | 15-20 minutes |

Note: RPO improves to near-zero for stateful workloads once daily backups
are configured and application-level backup strategies are implemented.
