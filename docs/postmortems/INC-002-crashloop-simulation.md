# INC-002 — Incident Simulation: Deliberate CrashLoopBackOff

**Incident ID:** INC-002
**Date:** 2026-07-04
**Severity:** SEV-3 (simulated)
**Duration:** ~10 minutes
**Author:** Tim
**Status:** Resolved — simulation complete
**Type:** Deliberate chaos exercise

---

## Objective

Validate that the PodCrashLooping alert rule fires correctly and delivers a Discord notification within the expected timeframe when a pod enters CrashLoopBackOff.

---

## What Was Done

Deployed a deliberately crashing pod using busybox with an exit 1 command. The pod crashed immediately on every start, entered CrashLoopBackOff, and was restarted repeatedly by Kubernetes.

---

## Timeline

| Time | Event |
|---|---|
| T+0 | crashloop-test pod deployed |
| T+0 | Pod crashes immediately on first start |
| T+1m | Pod enters CrashLoopBackOff |
| T+5-10m | Restart rate exceeds alert threshold |
| T+alert | PodCrashLooping alert fires in Prometheus |
| T+alert+30s | Discord notification received in alerts channel |

---

## Result

Alert fired successfully. Discord notification received. Full pipeline validated:

    Crashing pod → kube-state-metrics → Prometheus → PodCrashLooping rule → Alertmanager → Discord

---

## Cleanup

Deleted the test pod after alert was confirmed:

    kubectl delete pod crashloop-test

---

## Findings

- PodCrashLooping alert rule works correctly
- Alertmanager routing to Discord is functional
- Detection time from crash to notification: approximately 5-10 minutes
- Alert correctly identified pod name, namespace, and severity

---

## Improvement Identified

The 15-minute evaluation window means a rapidly crashing pod takes 5-10 minutes before the alert fires. For production environments a shorter window of 5 minutes would reduce detection time for critical workloads. Consider adding a faster-firing critical alert for pods restarting more than 5 times in 5 minutes.

---

## Lessons Learned

A single pod deletion does not trigger PodCrashLooping because Kubernetes restarts it cleanly. The alert requires sustained restart rate over the evaluation window. Deliberate crash simulation using a failing command is the correct way to test this alert path.
