---
name: gke-compute-classes
license: Apache-2.0
metadata:
  author: Google Cloud
  version: "1.0.0"
description: "GKE ComputeClasses (CCC): Priority-based node provisioning (NAC vs manual), fallbacks, and cost optimization."
---

# GKE ComputeClasses (CCC)

Decouple Pod requirements from infra implementation. Use for: Autopilot, Standard with NAC, or prioritized manual pools.

**Requirements:** GA features require GKE 1.31+. `priorityScore` requires GKE 1.35.2-gke.1842000+.

## Cheat Sheet

```yaml
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata: { name: example }
spec:
  nodePoolAutoCreation: { enabled: true } # Required for dynamic provisioning
  priorityDefaults: { location: { zones: [us-central1-a] } }
  priorities: # Tried top-to-bottom
  - machineFamily: n4     # Preferred (Intent-based)
    minCores: 16
    spot: false
  - machineType: e2-standard-4 # Specific fallback
    spot: true
  activeMigration: { optimizeRulePriority: true } # Drift pods to higher priority
```

| Component | Key Logic / Selection |
|-----------|--------------------|
| **Selection** | `nodeSelector: cloud.google.com/compute-class: <name>` |
| **Logic** | Sequential traversal. Backoff on stockout. Tie-break: lowest cost. |
| **Scores** | `priorityScore`: 1-1000 (Higher = Preferred). Tie-break: lowest cost. |
| **Config** | `nodePoolConfig`: { imageType, sa, labels, taints }. Applies to NAC nodes. |
| **Drift** | `activeMigration`: honors PDBs to move pods to better nodes. |

## Reference Directory

| Scenario | Trigger Keywords | Reference |
|----------|-----------------|-----------|
| **Fields & Spec** | YAML shape, `priorities`, `nodePoolConfig`, `priorityScore`, `autoscalingPolicy` | [ccc-crd-fields.md](./references/ccc-crd-fields.md) |
| **Binding & Provisioning** | NAC setup, manual pool binding, intent-based vs strict | [ccc-provisioning-methods.md](./references/ccc-provisioning-methods.md) |
| **Prioritization & Fallbacks** | traversal order, limits, GPU/TPU patterns, Spot/OD fallbacks | [ccc-prioritization.md](./references/ccc-prioritization.md) |
| **Cost Optimization** | FlexCUD alignment, Spot vs OD tiering | [ccc-cost-optimization.md](./references/ccc-cost-optimization.md) |
| **Lifecycle & Updates** | consolidation (scale-down), drift, activeMigration, update behavior | [ccc-lifecycle.md](./references/ccc-lifecycle.md) |
| **Gotchas & CUDs** | DWS, disk generation, Service Mesh, `AnyBestEffort`, FlexCUDs | [ccc-gotchas-and-cuds.md](./references/ccc-gotchas-and-cuds.md) |
| **Migrations** | Karpenter to CCC, NodePool mapping, weight translation | [ccc-karpenter-migration.md](./references/ccc-karpenter-migration.md) |
| **Debugging** | scale-up failure, stockout, event logs, pending pods | [ccc-debug.md](./references/ccc-debug.md) |

## Core Patterns
1. **GPU/TPU:** `Reservation -> DWS FlexStart -> On-Demand -> Spot` (Training).
2. **Cost:** `Spot (Preferred) -> On-Demand (Floor)`.
3. **Latency:** `Manual Pool (Pre-warmed) -> NAC (Dynamic Fallback)`.

## Assets

> **Agent Instruction:** When copying or adapting any of these assets, you MUST ask the user which Google Cloud region and zone(s) they want to deploy into. Do not blindly copy the hardcoded `us-central1` zones from the examples into user environments without confirmation.

- [L4 Inference](./assets/genai-inference-g4-compute-class.yaml) | [TPU Training](./assets/tpu-v5e-training-compute-class.yaml)
- [Postgres Tuning](./assets/postgres-primary-compute-class.yaml) | [Spot Tie-break](./assets/spot-cost-tiebreak-compute-class.yaml)
