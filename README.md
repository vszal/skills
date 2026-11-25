# GKE agent skills (archived)

This repository is retired and archived. Both Google Kubernetes Engine (GKE) agent skills have moved to the official Google skills repository at [github.com/google/skills](https://github.com/google/skills).

Git history is preserved here for reference, but all future updates ship exclusively from `google/skills`.

## Migration guide

If you previously installed skills from `vszal/skills`, remove the legacy entries (or run `npx skills update` to clear obsolete references) and reinstall them from `google/skills`:

```bash
# 1. Remove the retired skills from vszal/skills (add -g for global installs)
npx skills remove gke-compute-classes gke-cluster-autoscaler

# Optional: refresh existing skill lockfiles
npx skills update

# 2. Install the official skills from google/skills (add -g for global installs)
npx skills add google/skills -s gke-compute-classes gke-cluster-autoscaler
```

## Official skill locations

| Skill | Description | Official location |
| :--- | :--- | :--- |
| **gke-compute-classes** | Configuring, optimizing, and troubleshooting GKE custom ComputeClasses, priority fallback ladders, and node pool auto-creation. | [github.com/google/skills/tree/main/skills/cloud/gke-compute-classes](https://github.com/google/skills/tree/main/skills/cloud/gke-compute-classes) |
| **gke-cluster-autoscaler** | Enabling, tuning, and debugging GKE Cluster Autoscaler, consolidation, scale-up backoffs, and capacity buffers. | [github.com/google/skills/tree/main/skills/cloud/gke-cluster-autoscaler](https://github.com/google/skills/tree/main/skills/cloud/gke-cluster-autoscaler) |

## Related repositories

- **[vszal/gke-custom-compute-class-examples](https://github.com/vszal/gke-custom-compute-class-examples)**: Remains active for runnable ComputeClass manifests, scale demos, and configuration examples (no official Google equivalent exists).
