# INC-006 — G4 Cluster Outage: Ethernet NIC Hardware Failure

**Incident ID:** INC-006
**Date:** 2026-07-11
**Severity:** SEV-2
**Duration:** Approximately 2 hours
**Author:** Tim
**Status:** Resolved — watchdog implemented

---

## Summary

The G4 compute node lost all network connectivity due to hardware failure on the ethernet NIC (nic0, e1000e driver). All 3 k3s nodes became unreachable simultaneously. NodeDown alerts fired for all 3 node-exporters within 2 minutes via Discord.

The WiFi interface (wlp0s20f3) remained connected and the G4 host itself retained internet access, but the faulty NIC was corrupting the vmbr0 bridge causing one-way ARP — requests went out but replies were blocked. This isolated all 3 k3s VMs.

Resolution required a full G4 reboot to reset the NIC driver state. Following recovery, network watchdog scripts were deployed on both G4 and NUC5 to auto-recover from future network failures without manual intervention.

---

## Timeline

| Time | Event |
|---|---|
| ~09:50 | NodeDown alerts fire for all 3 node-exporters |
| ~09:50 | Discord notifications received |
| ~09:52 | Investigation begins — G4 unreachable |
| ~09:55 | Physical access to G4 — wpa_state=COMPLETED but DORMANT state |
| ~09:56 | Kernel errors identified: e1000e NETDEV WATCHDOG transmit queue timed out |
| ~10:00 | Bringing nic0 down clears interference, G4 host connectivity restored |
| ~10:05 | VMs still unreachable — bridge has no uplink without nic0 |
| ~10:15 | Multiple recovery attempts: NAT, proxy ARP, static ARP — all failed |
| ~10:25 | G4 rebooted — NIC driver reset |
| ~10:28 | All 3 k3s nodes Ready, cluster recovered |
| ~10:43 | Network watchdog deployed on G4 and NUC5 |

---

## Root Cause

Hardware failure on the G4 ethernet NIC (nic0, Intel e1000e driver). The NIC entered a state where its transmit queue timed out repeatedly, causing the kernel watchdog to fire. In this state the NIC was corrupting the vmbr0 bridge — ARP requests from VMs were forwarded out but ARP replies from the router were not forwarded back, creating a one-way ARP black hole that isolated all VMs.

The WiFi interface remained healthy throughout but could not substitute for the bridge NIC due to Linux limitations on bridging WiFi interfaces in infrastructure mode.

---

## Contributing Factors

- Single ethernet NIC dependency for VM bridge connectivity
- No automated recovery for NIC hardware failures
- QEMU guest agent not running on VMs, limiting recovery options
- Aging hardware — NUC5i5RYH era G4 ethernet NIC showing age

---

## Impact

| Metric | Value |
|---|---|
| Detection time | 2 minutes via NodeDown alert |
| Total outage duration | ~2 hours |
| Services affected | All 3 k3s nodes, all Kubernetes workloads |
| NUC5 affected | No |
| Data loss | None |
| Factorio world data | Intact — PVC persisted |

---

## Resolution

G4 reboot reset the e1000e NIC driver state restoring normal bridge operation.

Permanent mitigation: network watchdog scripts deployed on both G4 and NUC5 via systemd timer running every 2 minutes. On gateway unreachable, G4 watchdog resets nic0 and vmbr0. NUC5 watchdog reconnects WiFi. Discord alert fires if auto-recovery fails.

---

## What Went Well

- NodeDown alert fired within 2 minutes
- NUC5 monitoring remained operational throughout
- Factorio world data intact on PVC
- ArgoCD resynced automatically after cluster recovery

## What Went Poorly

- 2 hour outage for what was ultimately a reboot fix
- No automated recovery — required physical access and multiple failed attempts
- QEMU guest agent not running limited recovery options inside VMs

---

## Action Items

| Action | Status |
|---|---|
| Deploy network watchdog on G4 | Done |
| Deploy network watchdog on NUC5 | Done |
| Enable QEMU guest agent on k3s VMs | Open |
| Monitor e1000e NIC health | Open |
| Consider RAM upgrade to allow larger VM allocation | Open |

---

## Lessons Learned

1. Hardware failures are unpredictable. The e1000e NIC failure was not caused by any configuration change — it simply failed. Having a watchdog that auto-recovers from the most common failure mode (bridge reset) reduces MTTR significantly.

2. A reboot is a valid recovery strategy. After 90 minutes of attempting surgical fixes, a reboot resolved the issue in 3 minutes. Sometimes the fastest path to recovery is the simplest one.

3. Detection was excellent, recovery was not. The alerting pipeline worked perfectly — Discord notification within 2 minutes. The gap was automated recovery. The watchdog closes that gap.

4. QEMU guest agent should be running on all VMs. Not having it severely limited recovery options when VMs were isolated — couldn't exec commands, set passwords, or inspect state without physical console access.
