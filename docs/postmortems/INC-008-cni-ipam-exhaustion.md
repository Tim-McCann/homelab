# INC-008 — CNI IPAM Exhaustion from Repeated VM Restarts

**Incident ID:** INC-008
**Date:** 2026-07-19
**Severity:** SEV-2
**Duration:** ~3 hours
**Author:** Tim
**Status:** Resolved — watchdog updated, UE300 installed

---

## Summary

Following a recurring e1000e Hardware Unit Hang on the G4, the NUC5 g4-monitor
detected k3s VMs unreachable and began restarting all 3 VMs every 3 minutes.
Over several hours this caused Flannel's IPAM database (cbr0) to accumulate
hundreds of stale IP allocations until the entire 10.42.2.0/24 range was
exhausted. New pods were stuck in ContainerCreating with the error:

    no IP addresses available in range set: 10.42.2.1-10.42.2.254

Additionally, MetalLB's L2 status objects became stale after the disruption,
causing the Factorio service IP to be announced from the wrong node. Players
could not connect to the game server.

---

## Timeline

| Time | Event |
|---|---|
| ~06:00 | e1000e Hardware Unit Hang on G4 |
| ~06:02 | NodeDown alerts fire for all 3 k3s nodes |
| ~06:02 | g4-monitor detects k3s-cp-01 unreachable |
| ~06:02 | g4-monitor begins restarting VMs every 3 minutes |
| ~09:00 | Manual investigation begins |
| ~09:15 | cbr0 IPAM database found with 250+ stale entries |
| ~09:20 | cbr0 cleared via find -delete on both worker nodes |
| ~09:30 | Pods recover, cluster returns to healthy state |
| ~09:45 | MetalLB L2 status objects deleted, Factorio IP re-announced |
| ~10:00 | Factorio connection restored |
| ~10:30 | UE300 USB ethernet adapter installed, e1000e blacklisted |

---

## Root Cause

**Primary:** e1000e onboard ethernet NIC Hardware Unit Hang causing VM bridge
failure (same root cause as INC-006).

**Secondary:** g4-monitor had no cooldown on VM restarts. It attempted to
restart VMs every 3 minutes indefinitely. Each restart cycle:
1. Stopped and started VMs
2. VMs came up with new network interfaces
3. Old CNI IP allocations were never cleaned up
4. cbr0 IPAM database accumulated stale entries
5. After ~80 restart cycles, all 254 IPs in 10.42.2.0/24 were exhausted

**Tertiary:** MetalLB L2 status objects became immutable and stuck pointing
to the wrong node after the disruption, causing ARP to resolve the Factorio
service IP incorrectly.

---

## Impact

| Metric | Value |
|---|---|
| Duration | ~3 hours |
| Detection | NodeDown Discord alert within 2 minutes |
| k3s cluster | Completely unavailable |
| Factorio | Unavailable, then wrong IP after recovery |
| Data loss | None — PVC intact |

---

## Resolution

**Immediate:**
- Cleared cbr0 IPAM database on both worker nodes via find -delete
- Restarted k3s-agent on both workers
- Deleted stale MetalLB servicel2status objects
- Restarted MetalLB speaker and controller

**Permanent:**
- Updated g4-monitor to limit VM restarts to once per 30 minutes
- g4-monitor now clears CNI IPAM before VM restart
- Installed TP-Link UE300 USB ethernet as vmbr0 bridge NIC
- Blacklisted e1000e driver permanently — Hardware Unit Hangs eliminated

---

## What Went Well

- NodeDown alert fired within 2 minutes
- NUC5 monitoring remained operational throughout
- Factorio world data intact on PVC

## What Went Poorly

- g4-monitor had no restart cooldown — amplified a hardware failure
  into a full CNI exhaustion
- No automatic CNI cleanup on VM restart
- MetalLB L2 status corruption required manual intervention

---

## Action Items

| Action | Status |
|---|---|
| Add 30 min cooldown to g4-monitor VM restart | Done |
| Clear CNI IPAM before VM restart in g4-monitor | Done |
| Install UE300 USB ethernet as bridge NIC | Done |
| Blacklist e1000e permanently | Done |
| Add MetalLB L2 status recovery to cheatsheet | Done |
| Codify UE300 bridge config in Ansible | Done |

---

## Lessons Learned

1. Automated recovery without rate limiting can amplify an incident.
   A watchdog that restarts VMs indefinitely is worse than no watchdog
   for this failure mode. Always add cooldown periods to automated
   remediation.

2. CNI state must be cleaned up before restarting VMs. The IPAM
   database doesn't auto-clean on VM restart — it must be explicitly
   cleared to prevent exhaustion after repeated restarts.

3. MetalLB L2 status objects can become stale after cluster disruption.
   After recovery, always check service IPs are being announced correctly
   if services are unreachable despite running pods.

4. The hardware fix (UE300) eliminates the entire incident class.
   Every incident since INC-004 traces to the e1000e NIC. One $12
   USB adapter and a blacklist entry closes all of them permanently.
