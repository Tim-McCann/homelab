# INC-007 — Incident Simulation: NodeDown Alert Validation

**Incident ID:** INC-007
**Date:** 2026-07-12
**Severity:** SEV-3 (simulated)
**Duration:** ~5 minutes
**Author:** Tim
**Status:** Resolved — simulation complete
**Type:** Deliberate chaos exercise

---

## Objective

Validate that the NodeDown alert fires correctly when a worker node goes down,
observe Kubernetes behavior for different workload types, and document recovery
time from a single worker node failure.

---

## What Was Done

Deliberately shut down k3s-w-01 (VM 301, 192.168.1.31) from the Proxmox UI.
Monitored Prometheus alerts, node status, and pod behavior during the outage.
Restored the node by starting VM 301 from Proxmox UI.

---

## Timeline

| Time | Event |
|---|---|
| T+0 | k3s-w-01 shut down from Proxmox UI |
| T+0 | kubectl shows k3s-w-01 NotReady |
| T+2m | NodeDown alert fires in Prometheus |
| T+2m+30s | Discord notification received in alerts channel |
| T+5m | k3s-w-01 started from Proxmox UI |
| T+6m | k3s-w-01 Ready, all pods restored |

---

## Findings

### NodeDown alert works correctly

The NodeDown alert fired within 2 minutes of the node going down and delivered
a Discord notification within 30 seconds. The alert correctly identified the
node by instance (192.168.1.31:9100).

### StatefulSets do NOT reschedule automatically

Factorio (StatefulSet) remained assigned to k3s-w-01 throughout the outage and
showed Running status on a NotReady node. Factorio was effectively unavailable
during the entire outage — players could not connect.

This is intentional Kubernetes behavior. StatefulSets use stable network
identities and persistent storage — Kubernetes does not automatically reschedule
them to avoid split-brain scenarios where two instances might access the same
PVC simultaneously.

### Deployments reschedule automatically

System pods running as Deployments or DaemonSets were rescheduled to k3s-w-02
or remained operational on the control plane. Only StatefulSet workloads were
affected by the unavailability.

---

## Impact

| Metric | Value |
|---|---|
| Detection time | 2 minutes via NodeDown alert |
| Factorio availability | Unavailable for full outage duration |
| Cluster health | k3s-w-02 and control plane unaffected |
| Data loss | None — PVC data intact |
| Recovery time | ~1 minute after node restart |

---

## Alert Validated

NodeDown rule:

    up{job=~"node-.*"} == 0

Fired correctly. Discord notification received. Full pipeline validated:

    Node down -> node-exporter unreachable -> Prometheus -> NodeDown rule -> Alertmanager -> Discord

---

## Key Finding — StatefulSet Availability

For production stateful workloads, a single worker node failure causes full
service unavailability until the node recovers. Options to improve this:

1. Run multiple replicas with pod anti-affinity rules (not applicable for
   Factorio — only one server instance makes sense)
2. Accept the downtime and ensure fast node recovery (current approach)
3. Use pod disruption budgets to control scheduled downtime
4. Implement faster node failure detection and automated recovery

For Factorio specifically, the acceptable approach is fast node recovery via
the network watchdog (2-6 minutes automatic) plus PBS backup for data protection.

---

## Cleanup

VM 301 (k3s-w-01) restarted. Node returned to Ready status. Factorio pod
resumed normal operation on k3s-w-01.

---

## Lessons Learned

1. NodeDown alert works correctly — detection within 2 minutes, Discord
   notification confirmed.

2. StatefulSets and Deployments have fundamentally different failure behavior.
   Understanding this distinction is critical for designing resilient systems.
   Factorio going down with a single worker failure is expected and acceptable
   for a homelab game server.

3. Single worker failure does not affect the control plane or other workers.
   The cluster continues operating — only workloads on the failed node are
   affected.

4. Recovery is fast once the node comes back — k3s rejoins the cluster within
   ~60 seconds of the VM starting.
