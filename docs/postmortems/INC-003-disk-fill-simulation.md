# INC-003 — Incident Simulation: Disk Fill / DiskSpaceLow Alert

**Incident ID:** INC-003
**Date:** 2026-07-04
**Severity:** SEV-3 (simulated)
**Duration:** ~10 minutes
**Author:** Tim
**Status:** Resolved — simulation complete
**Type:** Deliberate chaos exercise

---

## Objective

Validate that the DiskSpaceLow alert rule fires correctly and delivers a
Discord notification when a node filesystem exceeds 80% capacity.

---

## What Was Done

SSHed into k3s-w-01 (192.168.1.31) and created a 28GB file using dd to
push disk usage from 11% to 82%, crossing the 80% alert threshold.

    dd if=/dev/zero of=/tmp/diskfill bs=1M count=28000

---

## Timeline

| Time | Event |
|---|---|
| T+0 | dd command started on k3s-w-01 |
| T+64s | 28GB file written, disk at 82% |
| T+65s | DiskSpaceLow alert enters Pending state in Prometheus |
| T+5m | DiskSpaceLow alert transitions to Firing |
| T+5m+30s | Discord notification received in alerts channel |
| T+6m | Test file deleted, disk returns to 11% |
| T+8m | DiskSpaceLow alert resolved, Discord resolved notification received |

---

## Result

Alert fired successfully. Discord notification received. Resolved notification
also received after cleanup. Full pipeline validated:

    High disk usage → node-exporter → Prometheus → DiskSpaceLow rule → Alertmanager → Discord → Resolved

---

## Alert Expression Validated

    (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 80

Evaluated every 15 seconds with a 5 minute for clause. Alert correctly
identified the instance, mountpoint, and filesystem.

---

## Cleanup

Deleted test file, disk returned to baseline:

    rm /tmp/diskfill

---

## Findings

- DiskSpaceLow alert rule works correctly
- 5 minute evaluation window gives adequate time to detect real disk growth
- Discord received both firing and resolved notifications
- node-exporter correctly exposes filesystem metrics excluding tmpfs
- Detection time from threshold crossed to notification: approximately 5 minutes

---

## Improvement Identified

28GB of free space on a 39GB disk means a real disk fill could happen
quickly under heavy workload. Consider adding a second faster-firing alert
at 90% with a shorter 2 minute window for critical disk pressure situations.

---

## Lessons Learned

Disk fill is one of the most common real-world incidents — databases grow,
logs accumulate, tmp directories fill up. Having an alert that fires before
the disk is completely full gives operators time to respond before services
start failing. The 80% threshold with a 5 minute window is appropriate for
infrastructure VMs but may need tuning for stateful workloads with variable
write patterns.
