# ADR-001 — k3s over kubeadm for Kubernetes distribution

**Date:** 2026-06-26  
**Status:** Accepted

## Context

Need to choose a Kubernetes distribution for a 3-node homelab cluster running on Proxmox VMs with 32GB total RAM on the compute node.

## Options Considered

| Option | Pros | Cons |
|---|---|---|
| **k3s** | Lightweight, fast startup, single binary, great for VMs, huge homelab community | Opinionated defaults (uses SQLite by default, Traefik built-in) |
| **kubeadm** | Most "real" production-like setup, full control | Complex to install, harder to rebuild, more ops overhead |
| **Talos Linux** | Immutable OS, API-driven, highly resume-worthy | Steep learning curve, harder to debug initially |

## Decision

**k3s** — installed via Ansible across 3 VMs provisioned by Terraform.

## Rationale

- 32GB RAM on compute node means resource efficiency matters
- k3s runs comfortably in VMs with 2–4 vCPU and 4–8GB RAM each
- Rebuilding the cluster from scratch via `terraform apply && ansible-playbook k3s.yml` takes under 10 minutes — this is itself a portfolio demonstration
- kubeadm's complexity delays getting to the higher-value portfolio work (GitOps, observability, SRE)
- k3s is production-used at scale (Rancher/SUSE backed), so it's credible on a resume

## Consequences

- Will use external etcd in a future iteration if adding a second control-plane node
- Traefik is bundled — will replace with Helm-managed Traefik for full config control
- SQLite backend is fine for single control-plane homelab use case
