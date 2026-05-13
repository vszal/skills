# API Deprecations & Webhooks

## Paused Auto-Upgrades
- GKE will **pause auto-upgrades** if it detects use of APIs that are deprecated in the target version.
- Use the **Deprecation Insights** in the Google Cloud Console to identify issues.

## Webhooks Blocking Upgrades
- **Webhooks:** Ensure Admission Webhooks (like Gatekeeper or Kyverno) do not intercept the `kube-system` namespace, as this can block the control plane upgrade.

## The 30-Day Rule
- GKE waits for **30 days** without detecting any deprecated API calls before automatically unpausing the upgrade.
- **Bypass the Wait:** If you have fixed the issue, you can bypass this wait by manually triggering the upgrade: 
  `gcloud container clusters upgrade [CLUSTER_NAME] --master --cluster-version [TARGET_VERSION]`