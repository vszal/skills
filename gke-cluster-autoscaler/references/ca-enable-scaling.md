# CA: Enabling Scaling (Standard)

## Cluster Autoscaler (CA) - Per Pool
Adds/removes nodes within `[min, max]` for an existing pool.
- **Enable (New Pool):**
  ```bash
  gcloud container node-pools create <POOL> \
    --enable-autoscaling --min-nodes=1 --max-nodes=10
  ```
- **Enable (Existing Pool):**
  ```bash
  gcloud container clusters update <CLUSTER> \
    --enable-autoscaling --node-pool=<POOL> \
    --min-nodes=1 --max-nodes=10
  ```
- **Total Node Bounds (Regional):** Use `--total-min-nodes` / `--total-max-nodes` to set a cluster-total floor/cap across zones.

## Node Auto-Provisioning (NAP) - Cluster-wide
Creates **new node pools** for pending pods within cluster-wide resource caps.
- **Enable:**
  ```bash
  gcloud container clusters update <CLUSTER> \
    --enable-autoprovisioning \
    --min-cpu=4 --max-cpu=200 \
    --min-memory=16 --max-memory=800
  ```
- **Add GPU Caps:**
  ```bash
  gcloud container clusters update <CLUSTER> \
    --enable-autoprovisioning \
    --max-accelerator=type=nvidia-l4,count=8
  ```

## Node Pool Auto-Creation (NAC) - Per ComputeClass
Preferred for per-workload shape control. Scoped to a CCC.
- **Enable:** Set `nodePoolAutoCreation.enabled: true` in the ComputeClass.
- **GKE 1.33.3+:** Works without cluster-wide NAP enabled.
