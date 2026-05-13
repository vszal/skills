#!/bin/bash
# Fetch GKE upgrade events from Cloud Logging for the last 24 hours.

PROJECT_ID=$(gcloud config get-value project)
CLUSTER_NAME=$1

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name>"
  exit 1
fi

gcloud logging read "resource.type=\"gke_cluster\" AND resource.labels.cluster_name=\"$CLUSTER_NAME\" AND jsonPayload.message:\"Upgrade\"" --limit 20 --format="table(timestamp, jsonPayload.message, severity)"
