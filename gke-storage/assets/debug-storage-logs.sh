#!/bin/bash
# GKE Storage Debugging Queries for Cloud Logging
# Use these queries in the Google Cloud Console (Logs Explorer) or via gcloud CLI.

# 1. GCE Persistent Disk (PD) CSI Driver Logs
# Debugs: Disk creation, attachment (Controller), and mounting (Node)
echo "--- GCE PD CSI Driver Logs ---"
echo 'resource.type="k8s_container"
resource.labels.namespace_name="kube-system"
resource.labels.container_name="gce-pd-driver"
textPayload:"AttachVolume" OR textPayload:"DetachVolume" OR textPayload:"NodePublishVolume"'

# 2. Filestore CSI Driver Logs
# Debugs: NFS instance creation, multi-share management, and mount issues
echo -e "\n--- Filestore CSI Driver Logs ---"
echo 'resource.type="k8s_container"
resource.labels.namespace_name="kube-system"
resource.labels.container_name="filestore-driver"
textPayload:"CreateInstance" OR textPayload:"DeleteInstance" OR textPayload:"NodePublishVolume"'

# 3. Cloud Storage FUSE CSI Driver Logs
# Debugs: GCS bucket mounting and sidecar container lifecycle
echo -e "\n--- GCS FUSE Driver & Sidecar Logs ---"
echo 'resource.type="k8s_container"
(resource.labels.container_name="gcs-fuse-driver" OR resource.labels.container_name="gcsfuse-sidecar")
textPayload:"mount" OR textPayload:"fuse"'

# 4. Kubernetes Storage Events (PVC/PV/Pod)
# Debugs: FailedMount, FailedAttachVolume, and Provisioning failures
echo -e "\n--- Kubernetes Storage Events ---"
echo 'resource.type="k8s_cluster"
jsonPayload.involvedObject.kind=("PersistentVolumeClaim" OR "Pod")
jsonPayload.reason=("FailedMount" OR "FailedAttachVolume" OR "FailedScheduling" OR "ProvisioningFailed")'

# Example usage with gcloud:
# gcloud logging read 'resource.type="k8s_container" resource.labels.container_name="gce-pd-driver" severity>=WARNING' --limit 10
