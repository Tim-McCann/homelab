# Postmortem Template

**Incident ID:** INC-XXX  
**Date:** YYYY-MM-DD  
**Severity:** SEV-1 / SEV-2 / SEV-3  
**Duration:** X hours Y minutes  
**Author:** Your Name  
**Status:** Draft / Final

---

## Summary

_One paragraph. What broke, how long, what was the user impact._

---

## Timeline

| Time (UTC) | Event |
|---|---|
| HH:MM | Alert fired / issue first detected |
| HH:MM | Investigation started |
| HH:MM | Root cause identified |
| HH:MM | Mitigation applied |
| HH:MM | Service restored |
| HH:MM | Incident closed |

---

## Root Cause

_What actually caused the incident. Be specific — "disk full" not "resource issue"._

---

## Contributing Factors

- Factor 1
- Factor 2

---

## Impact

| Metric | Value |
|---|---|
| Duration | X hours Y minutes |
| Services affected | list them |
| Users affected | estimated count |
| Data loss | None / describe |

---

## Detection

_How was the incident detected? Alert? User report? Manual observation?_  
_If detected by alert: which alert fired? How quickly after the issue started?_

---

## Response

_What did you do to investigate and fix the issue? What worked, what didn't?_

---

## Resolution

_What was the final fix? Was it a workaround or a real fix?_

---

## What Went Well

- Item 1
- Item 2

---

## What Went Poorly

- Item 1
- Item 2

---

## Action Items

| Action | Owner | Due Date | Status |
|---|---|---|---|
| Fix X to prevent recurrence | Name | YYYY-MM-DD | Open |
| Add alert for Y | Name | YYYY-MM-DD | Open |
| Update runbook for Z | Name | YYYY-MM-DD | Open |

---

## Lessons Learned

_What did this incident teach you about the system, the monitoring, or the process?_
