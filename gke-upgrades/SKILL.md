---
name: gke-upgrades
description: Expert guide for GKE upgrades (Release Channels, Control Plane/Node upgrades, Maintenance Windows). Use for upgrade strategies (Surge, Blue/Green), sequencing, troubleshooting, and best practices for availability. Use this skill whenever the user asks about GKE versioning, cluster maintenance, or upgrading nodes and control planes.
---

# GKE Upgrade Skill

Guidance on planning, executing, and troubleshooting upgrades in Google Kubernetes Engine. 

**Progressive Disclosure:** Do not guess. If a user asks about a specific topic, read the corresponding reference file below to get the exact GKE constraints, limitations, and CLI commands.

## Index of Topics

### Strategies & Configuration
- **[Surge vs. Blue/Green Strategies](./references/strategies-surge-bluegreen.md):** Configuration (`maxSurge`, `batchSize`), trade-offs, and defaults.
- **[Maintenance Windows & Exclusions](./references/maintenance-windows-exclusions.md):** Scheduling upgrades, the 32-day exclusion limit, paused upgrades/mixed-version states, and dynamic exclusions for batch jobs.
- **[Release Channels & Versioning](./references/channels-versioning.md):** Rapid, Regular, Stable, and Extended channels. Auto-upgrade timing, version skew policies, and tracking EOL dates to prevent forced upgrades.
- **[Rollout Sequencing](./references/sequencing.md):** Multi-environment topologies, `INELIGIBLE` status debugging, and 24-hour/30-day safety throttles.

### Constraints & Edge Cases
- **[Workload Availability](./references/workload-availability.md):** The strict 1-hour limit on PDBs and grace periods, handling stateful workloads, and Zonal vs Regional Control Plane downtime.
- **[Resource Constraints](./references/resource-constraints.md):** Upgrading GPU/TPU node pools using No-Surge configurations to avoid quota exhaustion, and using ComputeClasses for fallback capacity.
- **[GKE Autopilot](./references/autopilot.md):** Autopilot's 7-day `extended-duration` pods vs Standard's 1-hour limits, and managed upgrade behaviors.
- **[API Deprecations & Webhooks](./references/api-deprecations.md):** The 30-day pausing rule, bypassing the wait via CLI, and Admission Webhooks intercepting `kube-system`.

### Troubleshooting
- **[Troubleshooting & Recovery](./references/troubleshooting.md):** Recovering stalled Blue/Green rollbacks, checking `anetd`/Cilium logs for post-upgrade CNI/networking bugs, and querying operations logs.

## Quick Actions
- **Health Verification Scripts:** Use [log-upgrade-events.sh](./assets/log-upgrade-events.sh).
- **Example Configs:** View [blue-green-upgrade.yaml](./assets/blue-green-upgrade.yaml) or [surge-upgrade.yaml](./assets/surge-upgrade.yaml).