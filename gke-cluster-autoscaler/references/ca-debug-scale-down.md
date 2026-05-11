# CA: Debugging Scale-down

## Finding Blockers
**Asset:** `./assets/find-scale-down-blockers.sh`
- Categorizes `safe-to-evict: false`, bare pods, local storage, and tight PDBs.

## Common Causes
- **Bare Pods:** No controller; autoscaler won't evict.
- **Local Storage:** `emptyDir` on local SSD or `hostPath`.
- **Annotation:** `cluster-autoscaler.kubernetes.io/safe-to-evict: "false"`.
- **Floor:** `min-nodes` or `total-min-nodes` > 0.

## Segregating System Pods (Expert Pattern)
Symptom: `kube-system` pods (metrics-server, coredns) land on expensive nodes and pin them.
**Fix:** Segregate via namespace default CCC.
1. Apply a "cheap" `system-pool` CCC.
2. Label `kube-system` namespace:
   `kubectl label ns kube-system cloud.google.com/default-compute-class-non-daemonset=system-pool`
3. Result: System pods land on cheap nodes; expensive nodes can consolidate freely.
