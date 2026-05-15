# ComputeClass: Prioritization, Logic & Fallbacks


## Traversal & Tie-Breaking
- **Sequential:** Tried top-to-bottom. Unobtainable shapes get a **5-minute cooldown**. Max **~10 entries** (prevents infinite loops).
- **Tie-break (No Score):** Top entry wins. If multiple shapes match one rule, lowest unit cost wins.
- **Tie-break (`priorityScore`):** Int 1–1000 (Higher = Preferred). If one rule has a score, **all** must. Max **3 rules per score**. Tied rules evaluated together; lowest cost wins. (GKE 1.35.2+).

## Fallback Patterns
| Pattern | Priority Order | Rationale | Asset |
|---|---|---|---|
| Inference | Res -> Spot -> DWS -> OD | Spot instant capacity; replicas mask preemption. | `genai-inference-g4-compute-class.yaml` |
| Prod Training | Res -> DWS -> OD -> Spot | DWS wait acceptable. Spot preemption disruptive. | `tpu-v5e-training-compute-class.yaml` |
| Dev Training | Spot -> OD | Spot for cost; OD floor unblocks dev. | |
| Cost Batch | Spot -> OD | Use `priorityScore` to pick cheapest Spot family. | `spot-cost-tiebreak-compute-class.yaml` |
| Latency Hybrid | Manual -> Auto-creation | Skip auto-creation delay by hitting warm pools. | `manual-pool-tiebreak-compute-class.yaml` |

## Key Rules
- **No repetition:** Doesn't improve obtainability.
- **Vary dimensions:** Zone, Family, Capacity (Spot/OD).
- **Always include a floor:** End with high-availability OD (e.g., N4/E2) to prevent `Pending`.
- **Mixed Architectures:** Mix ARM (`n4a`) and x86 (`n4`) in `priorities[]`. Autoscaler skips incompatible shapes based on Pod constraints. **Must use multi-platform image builds.**
- **Spot Availability:** For CPU, if OD is out, Spot usually is too. For Accelerators, Spot often has capacity when OD doesn't.
