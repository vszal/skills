# Release Channels & Versioning

## Release Channels
Release channels automate version management based on stability needs.

| Channel | Stability | Use Case |
| :--- | :--- | :--- |
| **Rapid** | Lower | Testing new features and early bug fixes. |
| **Regular** | Balanced | Default channel for production workloads. |
| **Stable** | High | Mission-critical workloads where stability is paramount. |
| **Extended** | Highest | Long-term support for legacy applications. **Warning:** Requires *manual* intervention for minor upgrades; "set and forget" results in forced upgrades at end-of-support. |

### Tracking End-of-Support (EOL)
To prevent forced upgrades during critical periods:
- **Monitor Notifications:** Subscribe to GKE release notes via Pub/Sub notifications.
- **Console Monitoring:** Check the "Cluster Basics" tab in the Google Cloud Console regularly for specific "End of Support" dates.
- **Auto-Upgrade Timing:** Even within the same release channel and region, not all clusters are upgraded simultaneously. Rollouts are staggered by Google to manage risk and capacity.

### Version Skew Policy
- **Nodes** can be at most **two minor versions** behind the control plane.
- **Control Plane** is always upgraded first.
- **Auto-upgrades** are triggered automatically for channel-enrolled clusters.
- **Best Practice:** While version skew is supported, running mixed versions for extended periods can expose subtle bugs. Node pools should be upgraded soon after the control plane.

## Static Versions
If not using a channel, you must manually manage upgrades and stay within the supported version window.

## References
- [GKE Release Notes](https://cloud.google.com/kubernetes-engine/docs/release-notes)
- [Supported Versions](https://cloud.google.com/kubernetes-engine/docs/concepts/versioning-and-upgrades#versioning_and_support)
