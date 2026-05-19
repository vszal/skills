---
name: gke-compute-classes
description: "GKE ComputeClasses: Priority-based provisioning (node pool auto-creation vs manual), fallbacks, cost optimization."
---
# GKE ComputeClasses
Guidance on configuring, optimizing, and troubleshooting GKE ComputeClasses.

## Engagement Rules: Generalized First, Refine Later
ComputeClasses depend on zone availability, CUDs, and workload constraints.
**Do not block the user's initial request.** If asked for YAML/recommendations:
1. **Provide Generalized Answer Immediately:** Fulfill request using best practices and placeholders (`<YOUR-ZONE-HERE>`).
    *   **CRITICAL CUD RULE:** You MUST state that the provided machine families (e.g., N4, C4) are generic best-practice examples. You MUST explicitly state that the final choice of machine family should be aligned with the user's existing Committed Use Discounts (CUDs) or Reservations.
    *   **YAML REQUIREMENT:** Any generated YAML template MUST include a comment near the `machineFamily` field: `# IMPORTANT: Align machineFamily with your existing CUDs/Reservations`.
    *   **MUST label initial YAML as `EXAMPLE TEMPLATE - DO NOT DEPLOY`.**
    *   **STRICT SCHEMA RULE:** NEVER hallucinate fields. Do NOT use `spec.description`, `gvnic`, `transparentHugepageEnabled`, or `shutdownGracePeriodSeconds`. Use `bootDiskSize` (NOT `bootDiskSizeGb`).
    *   **YAML FORMATTING RULE:** NEVER quote integer or boolean values (e.g., use `bootDiskSize: 50`, not `bootDiskSize: "50"`). `imageType` MUST be lowercase.
    *   **CRITICAL AI/ML RULE:** DO NOT recommend Spot instances as the primary priority for AI/ML Inference, *even if the workload is stateless*. Accelerator node startup latency is severe. The correct priority is: `Reservations -> On-Demand -> DWS FlexStart -> Spot`.
    *   **CRITICAL PROVISIONING RULE:** Do NOT confuse node pool auto-creation with cluster-level Node Auto Provisioning. Starting with GKE `1.33.3-gke.1136000`, `nodePoolAutoCreation.enabled: true` in the ComputeClass achieves automatic node pools scoped directly to the ComputeClass. **It does NOT require turning on Node Auto Provisioning at the cluster level.**
    *   **CRITICAL TAINT RULE:** Do NOT add arbitrary or redundant taints inside the ComputeClass `nodePoolConfig.taints`. When using node pool auto-creation, ComputeClasses automatically taint nodes with `cloud.google.com/compute-class` and auto-tolerate workloads using this key. (Manual node pools still require the taint to be manually created). Adding an extra taint on top of this is redundant and breaks scheduling.
    *   **CRITICAL STATEFUL RULE:** For PV workloads, do NOT mix Gen 2 (PD) and Gen 4 (Hyperdisk) in `priorities[]`. Mix causes attach failures.
2. **Append Follow-Up Questions:** State that more context enables specific, cost-effective, reliable recommendations. Pin down missing context (Priority: CUDs first):
   - **Financial Constraints:** Do you have existing **Committed Use Discounts (CUDs)** or **Reservations** for specific machine families (e.g., N2, N4, C3)? This is the primary driver for machine family selection.
   *   **Workload Profile:** (Stateful vs stateless, use of `activeMigration`.)
   - **Cluster State:** Existing pools, auto-creation status.
   - **Infrastructure Constraints:** Target GCP region/zone.
   - **Pod Requests:** Ensure templates have CPU/Memory requests. Node pool auto-creation node sizing is based strictly on Pod *Requests*, not *Limits*.
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

