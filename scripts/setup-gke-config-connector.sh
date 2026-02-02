#!/bin/bash
# Setup GKE cluster with Config Connector for the GenAI Golden Path

set -e

# Configuration - modify these values
GCP_PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
CLUSTER_NAME="${CLUSTER_NAME:-golden-path-cluster}"
ZONE="${ZONE:-us-central1-a}"
NUM_NODES="${NUM_NODES:-3}"

echo "============================================"
echo "  GKE Config Connector Setup"
echo "============================================"
echo ""
echo "Configuration:"
echo "  Project:  $GCP_PROJECT_ID"
echo "  Cluster:  $CLUSTER_NAME"
echo "  Zone:     $ZONE"
echo "  Nodes:    $NUM_NODES"
echo ""

read -p "Continue with these settings? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Enable required APIs..."
gcloud services enable container.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable cloudresourcemanager.googleapis.com --project="$GCP_PROJECT_ID"
gcloud services enable iam.googleapis.com --project="$GCP_PROJECT_ID"

echo ""
echo "Step 2: Create GKE cluster with Config Connector..."
gcloud container clusters create "$CLUSTER_NAME" \
  --project="$GCP_PROJECT_ID" \
  --zone="$ZONE" \
  --num-nodes="$NUM_NODES" \
  --workload-pool="${GCP_PROJECT_ID}.svc.id.goog" \
  --addons=ConfigConnector

echo ""
echo "Step 3: Get cluster credentials..."
gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone="$ZONE" \
  --project="$GCP_PROJECT_ID"

echo ""
echo "Step 4: Create Config Connector service account..."
SA_NAME="config-connector-sa"
SA_EMAIL="${SA_NAME}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"

# Create service account if it doesn't exist
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$GCP_PROJECT_ID" &>/dev/null; then
    gcloud iam service-accounts create "$SA_NAME" \
      --project="$GCP_PROJECT_ID" \
      --display-name="Config Connector Service Account"
fi

echo ""
echo "Step 5: Grant required permissions..."
# Storage Admin
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.admin" \
  --condition=None

# Vertex AI Admin
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/aiplatform.admin" \
  --condition=None

# Service Usage Admin
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/serviceusage.serviceUsageAdmin" \
  --condition=None

# IAM Admin (for creating service accounts)
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountAdmin" \
  --condition=None

echo ""
echo "Step 6: Bind Kubernetes SA to GCP SA..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --project="$GCP_PROJECT_ID" \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
  --role="roles/iam.workloadIdentityUser"

echo ""
echo "Step 7: Configure ConfigConnector resource..."
cat <<EOF | kubectl apply -f -
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: "$SA_EMAIL"
EOF

echo ""
echo "Step 8: Wait for Config Connector to be ready..."
kubectl wait -n cnrm-system \
  --for=condition=Ready pod \
  -l cnrm.cloud.google.com/component=cnrm-controller-manager \
  --timeout=300s

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Config Connector is ready to use."
echo "You can now apply KRM manifests to create GCP resources."
echo ""
echo "Test with:"
echo "  kubectl get crds | grep cnrm"
echo ""
