---
name: gke-compute-classes
description: "GKE ComputeClasses: Priority-based provisioning (node pool auto-creation vs manual), fallbacks, cost optimization."
---
# GKE ComputeClasses
Guidance on configuring, optimizing, and troubleshooting GKE ComputeClasses.

## Engagement Rules: Generalized First, Refine Later
ComputeClasses depend on zone availability, CUDs, and workload constraints.
**Do not block the user's initial request.** If asked for YAML/recommendations:
1. **Provide Generalized Answer Immediately:** Fulfill request using best practices and placeholders (`<YOUR-ZONE-HERE>`). **MUST label initial YAML as `EXAMPLE TEMPLATE - DO NOT DEPLOY`.**
2. **Append Follow-Up Questions:** State that more context enables specific, cost-effective, reliable recommendations. Pin down missing context:
   - **Workload Profile:** Stateful vs stateless, `activeMigration`.
   - **Cluster State:** Existing pools, auto-creation status.
   - **Financial Constraints:** CUDs for machine series.
   - **Infrastructure Constraints:** Target GCP region/zone.
   - **Pod Requests:** Ensure templates have CPU/Memory requests (autoscaler requires them).
**Progressive Disclosure:** Do not guess syntax. Read reference files.

## Index
- **[CRD Fields](./references/compute-class-crd-fields.md):** `priorities`, `nodePoolConfig`, `whenUnsatisfiable`, storage, `nodeSystemConfig`.
- **[Provisioning Methods](./references/compute-class-provisioning-methods.md):** Auto vs Manual, Custom Init, Kueue Integration.
- **[Prioritization Logic](./references/compute-class-prioritization.md):** Traversal, `priorityScore` (tie-breaking), architectures.
- **[Lifecycle & Drift](./references/compute-class-lifecycle.md):** Consolidation, `activeMigration`.
- **[Cost Optimization](./references/compute-class-cost-optimization.md):** Spot-first, FlexCUDs, PDB throttling.
- **[Gotchas & Edge Cases](./references/compute-class-gotchas-and-cuds.md):** DWS limitations, Disk Generation traps, `AnyBestEffort`.
- **[Karpenter Migration](./references/compute-class-karpenter-migration.md):** Translating EKS Karpenter NodePools.
- **[Debugging Guide](./references/compute-class-debug.md):** GPU tolerations, `ScaleUpAnyway` traps, PV deadlocks, fragmentation.

## Quick Actions
- **Logs:** `assets/log-autoscaler-events.sh`.
- **Examples:** `assets/*.yaml` (Always ask for region/zone before copying).

