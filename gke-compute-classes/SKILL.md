---
name: gke-compute-classes
license: Apache-2.0
metadata:
  author: Google Cloud
  version: "1.0.0"
description: "GKE ComputeClasses (CCC): Priority-based node provisioning (NAC vs manual), fallbacks, and cost optimization."
---

# GKE ComputeClasses (CCC)

Guidance on configuring, optimizing, and troubleshooting GKE ComputeClasses. 

**Progressive Disclosure:** Do not guess configuration syntax. If a user asks about a specific topic, read the corresponding reference file below to get the exact fields, limitations, and YAML examples.

## Index of Topics

### Configuration & Architecture
- **[CRD Fields & Definitions](./references/ccc-crd-fields.md):** `priorities`, `nodePoolConfig`, `whenUnsatisfiable`, storage overrides, and `nodeSystemConfig` (kernel tuning).
- **[Provisioning Methods](./references/ccc-provisioning-methods.md):** Node Auto-Provisioning (NAC) vs. Manual pools, and Custom Node Initialization (DaemonSets).
- **[Prioritization Logic](./references/ccc-prioritization.md):** Sequential traversal, `priorityScore` (tie-breaking, round-robin), and handling mixed architectures (ARM/x86).

### Advanced Behaviors
- **[Lifecycle & Active Migration](./references/ccc-lifecycle.md):** Scale-down rules, consolidation thresholds, and `activeMigration` drift behavior.
- **[Cost Optimization](./references/ccc-cost-optimization.md):** Spot-first strategies, FlexCUD alignment, and throttling active migration with PDBs/annotations.
- **[Gotchas & Edge Cases](./references/ccc-gotchas-and-cuds.md):** DWS limitations, Disk Generation traps, and `AnyBestEffort` reservation bypasses.
- **[Karpenter Migration](./references/ccc-karpenter-migration.md):** Translating EKS Karpenter NodePools to GKE ComputeClasses.

### Troubleshooting
- **[Debugging Guide](./references/ccc-debug.md):** Missing GPU tolerations, `ScaleUpAnyway` traps, Zonal PV deadlocks, and the `imageType` fragmentation bug.

## Quick Actions
- **Logging Script:** To find the raw decisions made by the autoscaler, use [log-autoscaler-events.sh](./assets/log-autoscaler-events.sh).
- **Example YAMLs:** Found in the `assets/` directory (e.g., `spot-cost-tiebreak-compute-class.yaml`, `postgres-primary-compute-class.yaml`). *Note: Always ask the user for their target GCP region/zone before copying example configs.*
