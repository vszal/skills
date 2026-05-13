# Rollout Sequencing

Rollout sequencing in GKE allows for automated, controlled, multi-stage cluster upgrades across different environments (e.g., Development -> Staging -> Production).

## Topology & Release Channels
The standard approach assumes a 3-tier architecture, but Rollout Sequences must be adapted to your exact cluster topology:
- **Strict 3-Tier (3 Clusters):** Dev (Rapid) -> Staging (Regular) -> Prod (Stable).
- **Shared Lower Environments (2 Clusters):** If Dev and Staging share a cluster, that cluster becomes a single point of failure for lower environments. Enroll the shared cluster in the **Regular** channel (to avoid the high frequency of Rapid) and use it as the upstream for the Production cluster (Stable).

## Core Concepts
- **Sequence:** A linked list of up to five cluster groups (Fleets) defining the exact upgrade order.
- **Soak Time:** A mandatory waiting period (up to 30 days) that must pass after an upstream group's upgrades finish before the next downstream group begins its upgrade.
- **Target Version:** All clusters in a sequence must share the same release channel and minor version.
- **Upstream/Downstream:** Upstream refers to the preceding group (e.g., Staging), while downstream is the next group in the sequence (e.g., Production).

## Requirements
- **Fleets:** Clusters must be registered to Fleets, typically grouped by environment.
- **APIs & Permissions:** Fleet-related APIs must be enabled in the fleet host projects. You need `roles/gkehub.editor` on each project to create/modify sequences, and `roles/gkehub.viewer` to monitor.

## Configuration & Binding
- **Binding:** Clusters are grouped together by registering them to specific Fleets.
- **Setup:** Sequences are constructed via the Google Cloud Console, `gcloud container fleet clusterupgrade`, or Terraform by defining `upstream-fleet` dependencies.
- **Release Channels:** While Rollout Sequences control the timing between Fleets, combining them with Release Channels (e.g., Rapid for Dev, Regular for Staging, Stable for Prod) provides a comprehensive safety net.

## Troubleshooting & Overrides
- **Ineligible Clusters (Blocked Sequence):** A group may become `INELIGIBLE` preventing downstream rollouts. Common causes include:
  - **Version Discrepancy:** A cluster is on an older minor version.
  - **Safety Throttles:** A cluster was upgraded too recently (less than 24 hours for a patch version, or 30 days for a minor version).
- **Debugging:** Run `gcloud container fleet clusterupgrade describe --show-linked-cluster-upgrade` to identify the specific cluster causing fleet-wide ineligibility.
- **Unblocking Strategies:**
  - **Manual Intervention:** Manually upgrade the lagging clusters so their version matches the group's target version.
  - **Remove from Fleet:** Unregister the ineligible cluster from the Fleet to allow the rest of the group to complete and start the soak timer.
  - **Soak Overrides:** If an urgent fix is required, you can use `gcloud container fleet clusterupgrade add-upgrade-soaking-override` to set the soak time to zero for a specific version, immediately unblocking downstream upgrades.

## Smoke Testing
During the sequence, particularly after the KCP upgrade and before node upgrades complete, run smoke tests in upstream environments to verify API compatibility before the soak time expires.
