# INC-004 — G4 Full Cluster Outage: TP-Link Extender ARP Bridge Failure

**Incident ID:** INC-004
**Date:** 2026-07-06
**Severity:** SEV-2
**Duration:** Overnight — approximately 8 hours
**Author:** Tim
**Status:** Resolved — permanent fix applied

---

## Summary

The G4 compute node lost all network connectivity overnight after the ThinkPad control plane was powered off. All 3 k3s VMs became unreachable simultaneously. NodeDown alerts fired for all 3 node-exporters via Discord. The NUC5 edge node was unaffected.

Initial hypothesis was that the ThinkPad shutdown caused the outage by removing iptables NAT rules. This was later disproved by INC-005 which occurred with the ThinkPad running. The real root cause was the TP-Link Archer C20 extender losing its ARP bridge table on the G4's ethernet port, blocking ARP replies while allowing ARP requests to pass.

Permanent fix: configured the G4's built-in WiFi card (wlp0s20f3) as the primary uplink, eliminating the TP-Link ethernet bridge dependency entirely.

---

## Timeline

| Time | Event |
|---|---|
| ~22:00 | ThinkPad powered off |
| ~02:00 | TP-Link extender ARP bridge table expires on G4 port |
| ~02:02 | NodeDown alerts fire for all 3 node-exporters |
| ~02:02 | Discord notifications received |
| Next day | Investigation begins |
| +30 min | G4 confirmed isolated, ARP replies blocked |
| +45 min | TP-Link power cycled, G4 rebooted, connectivity restored |

---

## Root Cause

The TP-Link Archer C20 in WiFi repeater/extender mode maintains an ARP bridge table mapping MAC addresses to WiFi clients. This table has an expiry timer. When the ThinkPad powered off, a network disruption caused the extender to drop and not refresh the ARP entry for the G4s ethernet port. Subsequent ARP requests from the G4 were forwarded by the extender but ARP replies from the router were not forwarded back — creating a one-way communication black hole.

The G4 showed: carrier=1, operstate=up, link detected=yes, but all ARP entries in FAILED or STALE state and no gateway reachable.

The ThinkPad shutdown was a contributing trigger but not the root cause — INC-005 confirmed the same failure occurring with the ThinkPad running.

---

## Impact

| Metric | Value |
|---|---|
| Duration | ~8 hours undetected overnight |
| Detection | NodeDown Discord alert (2 min after failure) |
| Services affected | All 3 k3s nodes, all k3s workloads, ArgoCD, Factorio |
| NUC5 affected | No — on different extender port |
| Data loss | None — VMs were running, world save intact |

---

## Resolution

Temporary: Power cycle TP-Link extender + reboot G4.

Permanent: Configured G4 built-in WiFi (wlp0s20f3) as primary uplink:
- Installed wpasupplicant, iw, wireless-tools
- Connected to home WiFi via wpa_supplicant
- Removed gateway from vmbr0 in /etc/network/interfaces
- WiFi now handles G4 routing, ethernet bridge handles VM traffic only
- G4 no longer depends on TP-Link ethernet bridge

---

## What Went Well

- NodeDown alert fired within 2 minutes of failure
- Discord notification received correctly
- NUC5 monitoring remained operational throughout
- VMs were still running inside Proxmox, no data loss

## What Went Poorly

- G4 had a single point of failure — one ethernet path through an unreliable extender
- No automated recovery — required manual intervention
- Initial diagnosis was wrong (blamed ThinkPad shutdown)

---

## Action Items

| Action | Status |
|---|---|
| Configure G4 WiFi as primary uplink | Done |
| Remove gateway from vmbr0 config | Done |
| Write INC-005 postmortem | Done |
| Add G4 network resilience to known issues | Done |

---

## Lessons Learned

1. Single points of failure in network paths will eventually fail. The G4 had one path to the network through an unreliable consumer extender. Adding WiFi as a second path eliminates the single point of failure.

2. Initial diagnosis was wrong. The ThinkPad shutdown was a red herring — the real cause was the extender ARP table expiry. Always verify the root cause before documenting it.

3. Consumer WiFi extenders in repeater mode are not reliable infrastructure. ARP bridge tables expire, ports drop, and behavior is unpredictable under network disruptions. For server infrastructure, direct WiFi or wired connections are required.
