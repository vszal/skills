# CCC: Priority Logic & Tie-breaking

## Sequential Traversal
- Tried **top to bottom**.
- If a priority is unobtainable (stockout/quota), it enters backoff and CCC tries the next entry.
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

## Best Practices
- **Don't repeat rules.** Repetition does not improve obtainability.
- **Vary dimensions.** A good list varies by Zone, Family, and Capacity Type (Spot/OD).
- **Always include a floor.** Ensure the last priority is a high-availability option (e.g., On-Demand N4/E2) so the workload isn't stuck `Pending`.
