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

## Security Context
- **fsGroup:** Recursive permission changes on large volumes can take 30+ minutes.
- **Optimization:** Use `fsGroupChangePolicy: "OnRootMismatch"` to skip redundant recursive walks.
