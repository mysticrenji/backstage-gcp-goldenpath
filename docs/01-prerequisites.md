# Phase 0: Prerequisites

Before starting this tutorial, ensure you have all required tools and infrastructure configured.

## A. Local Development Tools

### Node.js (v22 or v24)

```bash
# Check version
node --version

# Install via nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 22
nvm use 22
```

### Yarn Package Manager

```bash
# Install globally
npm install --global yarn

# Verify
yarn --version
```

### Docker

```bash
# Check version
docker --version

# Ensure daemon is running
docker ps
```

### Git

```bash
git --version
```

## B. Cloud Infrastructure (GCP)

### Google Cloud Project

1. Create or select a GCP project with billing enabled
2. Note your Project ID (e.g., `my-genai-project-123`)

```bash
# Set your project
export GCP_PROJECT_ID="project-f30c097b-d89e-46b5-b14"
gcloud config set project $GCP_PROJECT_ID
```

### GKE Cluster with Config Connector

This is the critical component that turns YAML files into real cloud resources.

#### Why GKE Autopilot?

We chose **GKE Autopilot** over Standard GKE for this tutorial based on the following considerations:

**Cost Optimization**

- **Pay-per-pod pricing**: You are billed only for the CPU, memory, and storage that your pods request—no charges for unused node capacity
- **Automatic scale-to-zero**: When workloads are idle, Autopilot scales down infrastructure, eliminating costs during non-peak hours
- **No over-provisioning**: Eliminates the need to estimate and pre-provision node pools, avoiding wasted resources
- **Committed use discounts**: Compatible with GCP committed use discounts for predictable workloads

**Operational Excellence**

- **Fully managed nodes**: Google handles node provisioning, OS patching, security updates, and version upgrades
- **Automatic repair**: Unhealthy nodes are detected and replaced without manual intervention
- **Built-in monitoring**: Pre-configured with Cloud Operations (logging and monitoring) out of the box
- **Simplified capacity planning**: No need to manage node pools, machine types, or scaling policies

**Security Best Practices**

- **Workload Identity enabled by default**: Secure, keyless authentication between pods and GCP services
- **Shielded GKE nodes**: Provides verifiable node integrity with secure boot and vTPM
- **Container-Optimized OS**: Nodes run a hardened, minimal OS designed for containers
- **Enforced pod security**: Prevents privileged containers and enforces security contexts
- **Network policy support**: Native support for Kubernetes network policies

**Best Practices for This Tutorial**

- **Use resource requests**: Always define CPU and memory requests in your pod specs—Autopilot uses these for scheduling and billing
- **Set resource limits**: Define limits to prevent runaway containers from consuming excessive resources
- **Use namespaces**: Organize workloads by environment (dev, staging, prod) for better isolation
- **Enable Vertical Pod Autoscaler (VPA)**: Let Autopilot recommend optimal resource requests based on actual usage
- **Leverage regional clusters**: Autopilot uses regional deployment by default, providing high availability across zones

#### Create GKE Autopilot Cluster with Config Connector Add-on

```bash
# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable krmapihosting.googleapis.com

# Create Autopilot cluster with Config Connector addon
gcloud container clusters create-auto golden-path-cluster \
  --region europe-west1 \
  --project=${GCP_PROJECT_ID}

# Update the cluster with configconnector
# gcloud container clusters update golden-path-cluster --update-addons=ConfigConnector=ENABLED --region europe-west1


# Get credentials and configure kubeconfig
gcloud container clusters get-credentials golden-path-cluster \
  --region europe-west1 \
  --project=${GCP_PROJECT_ID}
```

> **Note**: Autopilot clusters use regional deployment by default for high availability. Workload Identity is enabled automatically, and the `--addons ConfigConnector` flag installs Config Connector as a managed add-on.

#### Configure kubeconfig for GKE

The `gcloud container clusters get-credentials` command automatically configures your local `kubectl` to connect to your GKE cluster by:

1. Fetching cluster endpoint and authentication details
2. Updating your `~/.kube/config` file with cluster credentials
3. Setting the current context to your new cluster

**Verify kubeconfig setup:**

```bash
# View current context
kubectl config current-context

# Should show: gke_<project-id>_europe-west1_golden-path-cluster

# Test connection
kubectl cluster-info
kubectl get nodes

# View all available contexts
kubectl config get-contexts
```

**Switch between multiple clusters (if needed):**

```bash
# List all contexts
kubectl config get-contexts

# Switch to a specific context
kubectl config use-context gke_${GCP_PROJECT_ID}_europe-west1_golden-path-cluster

# Set default namespace (optional)
kubectl config set-context --current --namespace=default
```

**Troubleshooting kubeconfig:**

If you encounter authentication issues:

```bash
# Refresh credentials
gcloud container clusters get-credentials golden-path-cluster \
  --region europe-west1 \
  --project=${GCP_PROJECT_ID}

# Verify gcloud authentication
gcloud auth list
gcloud auth application-default login

# Check kubectl can reach the cluster
kubectl version --short
```

#### Configure Config Connector Service Account

```bash
# Create service account for Config Connector
gcloud iam service-accounts create config-connector-sa \
  --display-name="Config Connector Service Account"

# Grant required permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/aiplatform.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"

# Bind Kubernetes service account to GCP service account
gcloud iam service-accounts add-iam-policy-binding \
  config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
  --role="roles/iam.workloadIdentityUser"
```

#### Configure ConfigConnector Resource

```bash
cat <<EOF | kubectl apply -f -
apiVersion: core.cnrm.cloud.google.com/v1beta1
kind: ConfigConnector
metadata:
  name: configconnector.core.cnrm.cloud.google.com
spec:
  mode: cluster
  googleServiceAccount: "config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
EOF
```

#### Verify Config Connector is Running

```bash
kubectl wait -n cnrm-system \
  --for=condition=Ready pod \
  -l cnrm.cloud.google.com/component=cnrm-controller-manager \
  --timeout=300s
```

#### Policy Controller
```
export CLUSTER_NAME="golden-path-cluster" 
gcloud container clusters update $CLUSTER_NAME \                                                                                         
    --enable-policy-controller \                                                                                                          
    --location=europe-west1
```
## C. Platform Credentials

### GitLab Personal Access Token (PAT)

1. Go to GitLab > Settings > Access Tokens
2. Create a new token with these scopes:
   - `api` (full control)
   - `read_user`
   - `write_repository`
3. Save the token securely

```bash
# Set as environment variable
export GITLAB_TOKEN='glpat-YOUR_GENERATED_TOKEN_HERE'
```

## Verification Checklist

Run this script to verify all prerequisites:

```bash
#!/bin/bash
echo "=== Checking Prerequisites ==="

echo -n "Node.js: "
node --version 2>/dev/null || echo "NOT INSTALLED"

echo -n "Yarn: "
yarn --version 2>/dev/null || echo "NOT INSTALLED"

echo -n "Docker: "
docker --version 2>/dev/null || echo "NOT INSTALLED"

echo -n "Git: "
git --version 2>/dev/null || echo "NOT INSTALLED"

echo -n "gcloud: "
gcloud --version 2>/dev/null | head -1 || echo "NOT INSTALLED"

echo -n "kubectl: "
kubectl version --client 2>/dev/null | head -1 || echo "NOT INSTALLED"

echo -n "GITLAB_TOKEN: "
[ -n "$GITLAB_TOKEN" ] && echo "SET" || echo "NOT SET"

echo "=== Done ==="
```

## Next Step

Once all prerequisites are met, proceed to [Phase 1: Backstage Setup](02-backstage-setup.md)
