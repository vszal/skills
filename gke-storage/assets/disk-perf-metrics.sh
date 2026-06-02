#!/bin/bash
# Disk PERFORMANCE / slow-I/O diagnostics for GKE nodes (Cloud Monitoring).
# Companion to debug-storage-logs.sh (which covers CSI/event LOGS, not perf).
# Find the VM instance backing the node, then chart these metric types in
# Metrics Explorer, filtering resource.labels.instance_id to that node's VM.
# Ref: https://cloud.google.com/compute/docs/disks/review-disk-metrics

echo "--- Disk performance metric types (Metrics Explorer / MQL) ---"
echo 'compute.googleapis.com/instance/disk/read_ops_count     # read IOPS'
echo 'compute.googleapis.com/instance/disk/write_ops_count    # write IOPS'
echo 'compute.googleapis.com/instance/disk/read_bytes_count   # read throughput'
echo 'compute.googleapis.com/instance/disk/write_bytes_count  # write throughput'

echo
echo "# Latency, queue length, and throttled operations: view on the VM's disk"
echo "# dashboard / via the Ops Agent. Read this way:"
echo "#   - Small random I/O is IOPS-bound; large sequential I/O is throughput-bound."
echo "#   - High 'throttled operations' or peak IOPS sitting at the provisioned/"
echo "#     size-derived ceiling  ==>  disk-bound. Fix: grow the disk (PD) or raise"
echo "#     provisioned IOPS/throughput (Hyperdisk); confirm the VM series can deliver it."
echo "#   - PD IOPS/throughput scale with disk size and are capped by VM machine-series"
echo "#     limits and shared egress bandwidth (see references/selection.md)."

echo
echo "# Example (gcloud) — write IOPS for one node VM over the last hour:"
echo "gcloud monitoring time-series list --project=PROJECT \\"
echo "  --filter='metric.type=\"compute.googleapis.com/instance/disk/write_ops_count\" AND resource.labels.instance_id=\"NODE_VM_ID\"' \\"
echo "  --interval-start-time=\$(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ)"
