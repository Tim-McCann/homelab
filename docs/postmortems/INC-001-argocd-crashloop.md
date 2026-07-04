# INC-001 — ArgoCD Component Crash Loop

**Incident ID:** INC-001  
**Date:** 2026-07-04  
**Severity:** SEV-3  
**Duration:** 34 hours undetected, 22 minutes to resolve after detection  
**Author:** Tim  
**Status:** Partially resolved — known limitation accepted  

---

## Summary

Two ArgoCD components, dex-server and applicationset-controller, entered crash loops shortly after ArgoCD was installed on the k3s cluster. The dex-server crashed due to a missing issuer URL configuration required for bare-metal deployments. The applicationset-controller crashed repeatedly due to intermittent API server connection failures caused by resource contention on the control plane VM.

Neither issue was detected for 34 hours until Prometheus alerting and Alertmanager Discord notifications were configured. The PodCrashLooping alert fired automatically and delivered a Discord notification to the alerts channel within 30 seconds. This incident directly demonstrates the consequences of deploying platform components before observability is in place.

The dex-server was fully resolved. The applicationset-controller crash loop was diagnosed to its root cause and accepted as a known limitation pending a RAM upgrade. Current GitOps workflows are unaffected — the application-controller managing actual deployments remained healthy throughout.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-07-02 20:00 | ArgoCD installed on k3s cluster |
| 2026-07-02 20:05 | dex-server and applicationset-controller begin crash looping, undetected |
| 2026-07-04 15:25 | Alertmanager configured with Discord webhook |
| 2026-07-04 15:26 | PodCrashLooping alert fires automatically |
| 2026-07-04 15:26 | Discord alerts channel notification received |
| 2026-07-04 15:30 | Investigation begins |
| 2026-07-04 15:35 | dex-server identified, missing url in argocd-cm ConfigMap |
| 2026-07-04 15:37 | dex-server fix applied, pod recovers |
| 2026-07-04 15:40 | applicationset-controller identified as OOMKilled, initial diagnosis |
| 2026-07-04 15:45 | Memory limits increased from none to 512Mi to 1Gi |
| 2026-07-04 15:50 | Crash loop continues despite memory increase |
| 2026-07-04 15:52 | Exit code 1 confirmed, not OOM, diagnosis revised |
| 2026-07-04 15:55 | Logs reveal: server is currently unable to handle the request |
| 2026-07-04 16:00 | Root cause revised to API server contention on underpowered control plane |
| 2026-07-04 16:05 | Decision made to accept as known limitation, no current impact |

---

## Root Cause

### dex-server — fully resolved

ArgoCD's dex authentication component requires an explicit url field in the argocd-cm ConfigMap to set the OIDC issuer URL. On bare-metal installations without a pre-configured ingress URL this must be set manually. The component crashes immediately without it. This is a documented bare-metal configuration requirement that was not applied at install time.

### applicationset-controller — known limitation

Initial diagnosis was OOMKill — incorrect. After memory limits were increased and crashes continued with exit code 1, log analysis revealed the actual error: the server is currently unable to handle the request.

The controller loses connectivity to the Kubernetes API server under load. The control plane VM is allocated only 2 vCPU and 3GB RAM. When multiple ArgoCD controllers simultaneously query the API server, it becomes temporarily unable to serve requests, causing the applicationset-controller to crash. This is a resource contention issue, not a software bug.

---

## Contributing Factors

- ArgoCD installed without a bare-metal configuration checklist
- No alerting in place during initial platform deployment, causing a 34-hour blind spot
- Control plane VM undersized for running full ArgoCD stack at 2 vCPU and 3GB RAM
- No resource requests or limits defined at ArgoCD install time
- Initial OOMKill diagnosis was incorrect, memory limits increased before logs were checked
- G4 compute node limited to 16GB RAM total split across 3 VMs

---

## Impact

| Metric | Value |
|---|---|
| Detection gap | 34 hours |
| Time to detect after alerting configured | 30 seconds |
| Time to resolve dex-server | 7 minutes |
| Total investigation time | 35 minutes |
| GitOps sync affected | No, application-controller remained healthy |
| ApplicationSet features affected | Yes, unavailable for duration |
| Data loss | None |
| User-facing impact | None |

---

## Detection

Detected automatically via PodCrashLooping Prometheus alert rule evaluating restart rate over 15 minutes against all pods. Alert routed through Prometheus to Alertmanager to Discord webhook to the alerts channel.

Critical finding: This incident had been running for 34 hours before alerting was configured. The moment alerting went live, the notification fired within 30 seconds. This is the clearest possible demonstration of why observability must be deployed before platform components, never after.

---

## Resolution

### dex-server — fully resolved

Patched the argocd-cm ConfigMap to add the missing url field pointing to the ArgoCD server IP, then rolled out a restart of the dex-server deployment. Pod recovered immediately and has remained stable.

### applicationset-controller — accepted as known limitation

Memory limits were added as correct practice regardless of root cause. Crash loop continued due to API server contention, which memory limits cannot fix. Decision: accept as known limitation. ApplicationSets are not currently in use, so impact on GitOps workflows is zero. The application-controller managing actual deployments is healthy.

Permanent fix: Upgrade G4 to 32GB RAM and resize control plane VM to 4GB. Estimated effort 30 minutes after RAM kit arrives.

---

## What Went Well

- PodCrashLooping alert fired correctly the moment alerting was configured
- Discord notification delivered in under 30 seconds
- dex-server resolved in under 7 minutes once detected
- ArgoCD application-controller remained healthy throughout
- Investigation correctly revised initial OOMKill diagnosis after log analysis
- Reasoned decision to accept limitation rather than over-provision resources

## What Went Poorly

- 34-hour detection gap due to no alerting at platform deployment time
- ArgoCD installed without bare-metal configuration checklist
- No resource limits defined at install time
- Initial diagnosis was wrong, memory limits bumped before logs were checked
- Control plane VM undersized from the start, should have been caught in capacity planning

---

## Action Items

| Action | Owner | Due | Status |
|---|---|---|---|
| Add resource limits to all ArgoCD components | Tim | 2026-07-05 | Done |
| Fix dex-server via argocd-cm URL config | Tim | 2026-07-04 | Done |
| Create ArgoCD bare-metal install runbook | Tim | 2026-07-10 | Open |
| Always deploy observability before platform components | Tim | Ongoing | Process change |
| Upgrade G4 to 32GB RAM | Tim | TBD | Open |
| Add memory headroom alert node above 85 percent for 5 minutes | Tim | 2026-07-07 | Open |
| Review all platform component resource limits | Tim | 2026-07-07 | Open |

---

## Lessons Learned

1. Observability must precede platform components. A 34-hour crash loop went completely unnoticed because alerting was not configured yet. The moment it was configured, detection was instantaneous. Monitoring infrastructure must be deployed first — everything else deploys into an already-observable environment.

2. Check logs before changing resource limits. The initial OOMKill diagnosis led to unnecessary memory limit increases. The correct sequence is always: observe the exit code, pull the logs, identify the actual error, then make changes. Changing configuration based on assumptions wastes time and can mask the real problem.

3. Not every incident requires immediate full resolution. The applicationset-controller crash loop is a known resource constraint with zero current user impact. Accepting it as a documented limitation with a clear permanent fix identified and scheduled is the right call. Documented known issues are preferable to undocumented hacks.

4. Resource limits are not optional. Kubernetes does not enforce resource usage without explicit limits. On memory-constrained nodes, any component without limits is a potential OOM victim that can starve other workloads. All production workloads should define both requests and limits at deployment time.
