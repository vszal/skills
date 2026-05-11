# CCC: Fallback Patterns (GPU/TPU/Cost)

## Pattern 1: Accelerator Obtainability (GPU/TPU)
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

## Pattern 2: Cost-Optimized Batch
`Spot (Preferred) -> On-Demand (Safety Floor)`
- Use `machineFamily` spread with `priorityScore` to pick the cheapest available Spot family.
- [Asset: spot-cost-tiebreak-compute-class.yaml](../assets/spot-cost-tiebreak-compute-class.yaml)

## Pattern 3: Latency Hybrid
`Manual Pools (Standard) -> NAC (Dynamic Fallback)`
- Skip NAC provisioning delay by hitting warm pools first.
- [Asset: manual-pool-tiebreak-compute-class.yaml](../assets/manual-pool-tiebreak-compute-class.yaml)

## Key Rules
- **Mixed Architectures:** Avoid falling back between different chip types (e.g. TPU to GPU) unless the PodSpec supports multi-arch/drivers.
- **Spot for CPU:** If On-Demand is exhausted in a zone, Spot usually is too.
- **Spot for Accelerator:** Spot often has capacity even when On-Demand doesn't.
