# ComputeClass: Prioritization, Logic & Fallbacks

## Sequential Traversal
- Tried **top to bottom**.
- If a priority is unobtainable (stockout/quota), it enters backoff and ComputeClass tries the next entry.
- **Limit:** Cap list at **~10 entries**. Longer lists may loop back to the top before reaching the bottom.

## Tie-breaking with `priorityScore`
Used when multiple rules have equal preference.
- **Score:** Integer 1–1000 (Higher = Preferred).
- **Rule:** If any rule has a score, **all** rules must.
- **Limit:** Max **3 rules per score**.
- **Result:** GKE evaluates tied rules together; tie-break is by **lowest unit cost**.
- *Requires GKE 1.35.2-gke.1842000+.*

## Tie-breaking (No Scores)
- If rules have no score, the top entry in the YAML is tried first.
- If multiple shapes/pools match a single intent-based rule, tie-break is by **lowest unit cost**.

## Fallback Pattern 1: Accelerator Obtainability (GPU/TPU)
Casts wide net for scarce capacity.

### Inference / Serving
`Reservation -> Spot -> DWS FlexStart -> On-Demand`
- **Spot High:** Instant capacity; replica count masks preemption.
- **DWS/OD Floor:** Fallback for serving.
- [Asset: genai-inference-g4-compute-class.yaml](../assets/genai-inference-g4-compute-class.yaml)

### Training
`Reservation -> DWS FlexStart -> On-Demand -> Spot`
- **DWS High:** Acceptable 3-min queue to land scarce capacity.
- **Spot Last:** Preemption forces checkpoint restarts; more disruptive than waiting for OD/DWS.
- [Asset: tpu-v5e-training-compute-class.yaml](../assets/tpu-v5e-training-compute-class.yaml)

## Fallback Pattern 2: Cost-Optimized Batch
`Spot (Preferred) -> On-Demand (Safety Floor)`
- Use `machineFamily` spread with `priorityScore` to pick the cheapest available Spot family.
- [Asset: spot-cost-tiebreak-compute-class.yaml](../assets/spot-cost-tiebreak-compute-class.yaml)

## Fallback Pattern 3: Latency Hybrid
`Manual Pools (Standard) -> node pool auto-creation (Dynamic Fallback)`
- Skip node pool auto-creation provisioning delay by hitting warm pools first.
- [Asset: manual-pool-tiebreak-compute-class.yaml](../assets/manual-pool-tiebreak-compute-class.yaml)

## Key Rules & Best Practices
- **Don't repeat rules.** Repetition does not improve obtainability.
- **Vary dimensions.** A good list varies by Zone, Family, and Capacity Type (Spot/OD).
- **Always include a floor.** Ensure the last priority is a high-availability option (e.g., On-Demand N4/E2) so the workload isn't stuck `Pending`.
- **Mixed Architectures:** You can mix multiple architectures (e.g., `n4a` for ARM and `n4` for x86) in a single `priorities[]` array. The Cluster Autoscaler will skip incompatible shapes if the Pod specifies an architecture constraint (e.g., via `nodeSelector` or affinity for `kubernetes.io/arch`). **Best Practice:** Use multi-platform container image builds ([docs](https://docs.docker.com/build/building/multi-platform/)) to allow seamless fallback between architectures without crashing pods.
- **Spot for CPU:** If On-Demand is exhausted in a zone, Spot usually is too.
- **Spot for Accelerator:** Spot often has capacity even when On-Demand doesn't.
