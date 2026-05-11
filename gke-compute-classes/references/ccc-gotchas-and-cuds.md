# CCC: Gotchas, CUDs & Constraints

## Common Traps
- **`AnyBestEffort` Reservation:** Bypasses CCC priorities and falls back to On-Demand at the GCE level. Avoid; use `Specific` affinity.
- **Reservations are Zonal:** Pin zones via `reservations.specific[].zones` on the priority. Don't use `priorityDefaults.location` (collides with `Specific`).
- **Disk Generation:**
    - **Gen 4** (`n4`, `c4`): Requires **Hyperdisk**.
    - **Gen 2** (`n2`, `c2`): Requires **Persistent Disk**.
    - *Rule:* Don't mix Gen 2 and Gen 4 priorities for workloads with attached PVs (attach will fail on fallback).
    - *Reference:* [Asset: postgres-primary-compute-class.yaml](../assets/postgres-primary-compute-class.yaml)

## Provisioning Nuance
- **DWS FlexStart:** Queued (~3 min). `maxRunDurationSeconds` doesn't help obtainability.
- **CCC ≠ Full Node API:** NAC doesn't support every `gcloud node-pools create` flag. If missing, use a **Manual Pool** bound to the CCC.

## Flexible CUDs (FlexCUDs)
- **Portable:** Discount follows whichever family the CCC picks.
- **Coverage:** vCPU/Memory on most families (C3, N2, N4, etc.).
- **Exclusions:** GPUs, TPUs, Hyperdisk, Spot.
- **Strategy:** Leverage FlexCUDs for the **On-Demand floor** of your CCC.

## System Configuration Allowlist
GKE allows only specific `sysctls` and `kubeletConfig` fields.
- **Check CRD:** `kubectl describe crd computeclasses.cloud.google.com` for the authoritative allowlist.
- **Symptoms:** Unsupported keys show up in `status.conditions`.
- **Version Gating:** Many fields (e.g. `singleProcessOOMKill`) require 1.33+ or 1.34+.
