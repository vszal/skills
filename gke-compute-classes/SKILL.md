---
name: gke-compute-classes
license: Apache-2.0
metadata:
  author: Google Cloud
  version: "1.0.0"
description: "Design, implement, and optimize GKE ComputeClasses for declarative node configuration and priority-based autoscaling. Covers intent-based provisioning, NAC (Node Pool Auto-Creation) vs. manual pools, Spot fallback strategies, GPU/TPU obtainability, Karpenter-to-CCC migration, and performance tuning (sysctls, hugepages)."
---

# GKE ComputeClasses

GKE ComputeClasses (CCC) provide a declarative way to define node requirements and provisioning priorities. They decouple workload requirements (in PodSpecs) from infrastructure implementation (in CCCs), enabling platform teams to manage fleet-wide node configurations, fallback strategies, and cost optimization.

## Reference Directory

Load the relevant reference based on trigger keywords. Prefer the most specific match.

| Scenario | Trigger Keywords | Reference |
|----------|-----------------|-----------|
| **Create & Basics** | create CCC, define ComputeClass, NAC vs manual, intent-based, node pool binding, whenUnsatisfiable | [gke-compute-classes-create.md](./references/gke-compute-classes-create.md) |
| **Optimization & Fallbacks** | fallback, priority list, Spot strategy, GPU/TPU obtainability, activeMigration, drift, FlexStart, CUDs, reservations | [gke-compute-classes-optimize.md](./references/gke-compute-classes-optimize.md) |
| **Karpenter Migration** | Karpenter migration, EKS to GKE, NodePool to CCC, weight to priority, disruption budgets | [gke-compute-classes-karpenter-migration.md](./references/gke-compute-classes-karpenter-migration.md) |
| **Troubleshooting** | CCC status, scale-up failure, stockout, event logs, pending pods, scheduling conflict | [gke-compute-classes-debug.md](./references/gke-compute-classes-debug.md) |

## Core Patterns

### 1. The Obtainability Fallback (GPU/TPU)
Always design for "Stockouts" by providing multiple machine families or zones.
- **Top Priority:** Preferred accelerator (e.g., L4 GPU on G2)
- **Fallback:** Secondary accelerator or different zone
- **Strategy:** Use `activeMigration: true` to move workloads back to the preferred tier when capacity returns.

### 2. Spot-to-On-Demand Fallback
Maximize savings while maintaining availability.
- **Top Priority:** Spot VMs (lowest cost)
- **Fallback:** On-Demand VMs (guaranteed capacity)
- **Asset:** [spot-cost-tiebreak-compute-class.yaml](./assets/spot-cost-tiebreak-compute-class.yaml)

### 3. Latency vs. Obtainability (Hybrid)
- **Top Priority:** Manual node pools (warm capacity, zero-latency scheduling)
- **Fallback:** NAC (Node Pool Auto-Creation) (scale-to-zero, infinite horizontal scale)
- **Asset:** [manual-pool-tiebreak-compute-class.yaml](./assets/manual-pool-tiebreak-compute-class.yaml)

## Examples & Assets

| Goal | Asset |
|------|-------|
| GenAI Inference (L4) | [genai-inference-g4-compute-class.yaml](./assets/genai-inference-g4-compute-class.yaml) |
| TPU Training | [tpu-v5e-training-compute-class.yaml](./assets/tpu-v5e-training-compute-class.yaml) |
| Database Tuning (PG/Redis) | [postgres-primary-compute-class.yaml](./assets/postgres-primary-compute-class.yaml) |
| Statefully Optimized (N4) | [n4-stateful-optimized.yaml](../n4-stateful-optimized.yaml) |

## Best Practices
- **Prefer Intent-based:** Use `machineFamily` and `minCores`/`minMemoryGb` instead of strict `machineType` to allow GKE to find the best fit.
- **Default `whenUnsatisfiable`:** Leave as `DoNotScaleUp` for critical workloads to avoid landing on underpowered E2 instances (the default fallback).
- **Separation of Concerns:** Use one CCC per workload type (e.g., `stateless-web`, `stateful-db`, `gpu-inference`) to manage their lifecycles and costs independently.
