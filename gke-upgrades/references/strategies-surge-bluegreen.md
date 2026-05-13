# Upgrade Strategies

## 1. Surge Upgrades (Default)
A rolling upgrade method that replaces nodes incrementally.

### Configuration
- `maxSurge`: Number of extra nodes to create during upgrade.
- `maxUnavailable`: Number of nodes that can be offline simultaneously.

### Pros/Cons
- **Pros:** Faster for small clusters, uses less temporary quota.
- **Cons:** Workloads may be moved multiple times if surge is small.

## 2. Blue/Green Upgrades
Maintains the original pool (Blue) and a new pool (Green) simultaneously.

### Configuration
- `batchSize`: Number of nodes to upgrade at once.
- `soakDuration`: Time to wait after a batch is successful before proceeding.

### Pros/Cons
- **Pros:** Safer for critical workloads, easier rollback, "soak" time verification.
- **Cons:** Requires significant Compute Engine quota (double the pool size during upgrade).

## 3. Node Auto-Repair
Upgrades often trigger auto-repair if nodes fail health checks during the process.