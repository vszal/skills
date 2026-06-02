# Data Security & Encryption

Ensure storage compliance and protection in GKE.

## Encryption at Rest
- **Google-managed (Default):** Automatic encryption.
- **Customer-Managed Encryption Keys (CMEK):** High-compliance requirements.

### CMEK Implementation
1. **StorageClass:** Set `disk-encryption-kms-key` to the full KMS resource path.
2. **IAM:** Grant `Cloud KMS CryptoKey Encrypter/Decrypter` to the **Compute Engine Service Agent** in the KMS project:
   `service-[PROJECT_NUMBER]@compute-system.iam.gserviceaccount.com`
   *Use this command to apply the binding:*
   ```bash
   gcloud kms keys add-iam-policy-binding [KEY_NAME] \
     --location [LOCATION] --keyring [RING_NAME] \
     --member "serviceAccount:service-[PROJECT_NUMBER]@compute-system.iam.gserviceaccount.com" \
     --role "roles/cloudkms.cryptoKeyEncrypterDecrypter"
   ```

- **Permanence:** CMEK encryption on a Persistent Disk is irreversible — you cannot remove the key or decrypt an existing disk. To change encryption, create a new disk and migrate data. Never disable encryption as a performance optimization.
- **Least Privilege:** Grant only `roles/cloudkms.cryptoKeyEncrypterDecrypter` on the specific key to the Compute Engine Service Agent. Do NOT grant project-wide `Editor`/`Owner` to "unblock" provisioning.

## Pod Identity & Access
- **Workload Identity (Federation):** The only sanctioned way for pods to access GCS/Cloud APIs. NEVER embed a service-account JSON key in a Secret or ConfigMap.
- **hostPath:** Node-local, not RWX, and a node-escape / data-exfiltration risk. Never use as shared storage — use Filestore or GCS FUSE.

## Security Context
- **fsGroup:** Recursive permission changes on large volumes can take 30+ minutes.
- **Optimization:** Use `fsGroupChangePolicy: "OnRootMismatch"` to skip redundant recursive walks.
