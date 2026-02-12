# Phase 1: Backstage Installation & Setup

This phase sets up Backstage - "The Interface" where users define what they need.

## Step 1.1: Scaffold the Backstage App

Open your terminal and run the Backstage creator:

```bash
npx @backstage/create-app@latest
```

When prompted:
1. **Enter a name for the app:** `genai-platform`
2. **Select database:** `SQLite` (easiest for local development)

## Step 1.2: Enter the Project Directory

```bash
cd genai-platform
```

## Step 1.3: Configure GitLab Authentication

Backstage needs your GitLab PAT to publish repositories on your behalf.

### Set Environment Variable

```bash
export GITLAB_TOKEN='glpat-YOUR_GENERATED_TOKEN_HERE'
```

For persistence, add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
echo 'export GITLAB_TOKEN="glpat-YOUR_TOKEN"' >> ~/.bashrc
source ~/.bashrc
```

### Update app-config.yaml

Open `app-config.yaml` in your code editor and configure the integrations block:

```yaml
integrations:
  gitlab:
    - host: gitlab.com
      token: ${GITLAB_TOKEN}
      apiBaseUrl: https://gitlab.com/api/v4
```

## Step 1.4: Install GitLab Scaffolder Actions

The default Backstage installation needs the GitLab scaffolder plugin for the `publish:gitlab` action.

```bash
# Add the GitLab scaffolder backend module
yarn --cwd packages/backend add @backstage/plugin-scaffolder-backend-module-gitlab
```

### Register the Plugin

Edit `packages/backend/src/index.ts` and add:

```typescript
// Add this import
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitlab'));
```

## Step 1.5: Verify Installation

Start the development server:

```bash
yarn start
```

Open http://localhost:3000 in your browser. You should see the Backstage homepage.

## Project Structure After Setup

```
genai-platform/
├── app-config.yaml          # Main configuration
├── app-config.local.yaml    # Local overrides (gitignored)
├── app-config.production.yaml
├── packages/
│   ├── app/                 # Frontend React app
│   └── backend/             # Backend Node.js app
│       └── templates/       # Where we'll add our Golden Path
├── package.json
└── yarn.lock
```

## Troubleshooting

### Error: GITLAB_TOKEN not set

```bash
# Verify the variable is set
echo $GITLAB_TOKEN

# If empty, set it again
export GITLAB_TOKEN='glpat-YOUR_TOKEN'
```

### Error: Unable to connect to GitLab

1. Verify your token has the correct scopes
2. Check the `apiBaseUrl` in app-config.yaml
3. For self-hosted GitLab, update `host` and `apiBaseUrl` accordingly

### Port 3000 already in use

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# Or use a different port
PORT=3001 yarn dev
```

## Step 1.6: Deploy Backstage to Kubernetes (GKE)

Once Backstage is working locally, you can deploy it to GKE for production use.

### Build the Docker Image

Backstage ships with a multi-stage Dockerfile. Build and push to a container registry:

```bash
# Install dependencies and build the Backstage backend
yarn install --immutable
yarn build:backend

# Build the Docker image
docker image build . -f packages/backend/Dockerfile \
  --tag gcr.io/${GCP_PROJECT_ID}/backstage:latest

# Push to Google Container Registry
docker push gcr.io/${GCP_PROJECT_ID}/backstage:latest
```

> **Note**: Do not run `yarn tsc` as a standalone type-check step before building.
> Some upstream dependencies (`@azure/msal-*`, `@rjsf/core`) ship raw `.ts` source
> files that fail type-checking under the Backstage tsconfig. The `yarn build:backend`
> command handles TypeScript compilation internally via `backstage-cli` and builds
> successfully. You can also use the `scripts/build-and-push.sh` helper script to
> automate the full build-and-push workflow.

> **Tip**: If using Artifact Registry instead of GCR:
> ```bash
> docker tag gcr.io/${GCP_PROJECT_ID}/backstage:latest \
>   europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/backstage/backstage:latest
> docker push europe-west1-docker.pkg.dev/${GCP_PROJECT_ID}/backstage/backstage:latest
> ```

### Create a Kubernetes Namespace

```bash
kubectl create namespace backstage
```

### Create the Backstage Secrets

Backstage needs three secrets: the GitLab token (for creating repos via the scaffolder), the GitHub token (for reading templates from GitHub-hosted catalogs), and the PostgreSQL password (for the database).

```bash
kubectl create secret generic backstage-secrets \
  --namespace backstage \
  --from-literal=GITLAB_TOKEN=${GITLAB_TOKEN} \
  --from-literal=GITHUB_TOKEN=${GITHUB_TOKEN} \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 20)
```

Alternatively, apply the declarative manifest from `k8s/secret.yaml` with `envsubst`:

```bash
envsubst < k8s/secret.yaml | kubectl apply -f -
```

### Create the PostgreSQL Database

For production, use PostgreSQL instead of SQLite:

```yaml
# k8s/postgres.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: backstage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15-alpine
          ports:
            - containerPort: 5432
          env:
            - name: POSTGRES_DB
              value: backstage
            - name: POSTGRES_USER
              value: backstage
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: POSTGRES_PASSWORD
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
              subPath: data
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: backstage
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: backstage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
```

Apply the PostgreSQL manifest:

```bash
kubectl apply -f k8s/postgres.yaml
```

> **Note:** The `backstage-secrets` Secret (containing `GITLAB_TOKEN`, `GITHUB_TOKEN`, and `POSTGRES_PASSWORD`) should already exist from the earlier step. PostgreSQL reads `POSTGRES_PASSWORD` from it.

### Create the Backstage Deployment

```yaml
# k8s/backstage.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage-sa
      containers:
        - name: backstage
          image: ghcr.io/mysticrenji/backstage:latest
          ports:
            - containerPort: 7007
          env:
            - name: GITLAB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: GITLAB_TOKEN
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: GITHUB_TOKEN
            - name: POSTGRES_HOST
              value: postgres.backstage.svc.cluster.local
            - name: POSTGRES_PORT
              value: "5432"
            - name: POSTGRES_USER
              value: backstage
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: POSTGRES_PASSWORD
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          readinessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 30
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 60
            periodSeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: backstage
  namespace: backstage
spec:
  selector:
    app: backstage
  ports:
    - port: 80
      targetPort: 7007
  type: ClusterIP
```

### Create Backstage Service Account (Workload Identity)

If Backstage needs to access GCP resources directly:

```yaml
# k8s/backstage-sa.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage-sa
  namespace: backstage
  annotations:
    iam.gke.io/gcp-service-account: backstage-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com
```

Set up the GCP side:

```bash
# Create GCP service account for Backstage
gcloud iam service-accounts create backstage-sa \
  --display-name="Backstage Service Account"

# Bind Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  backstage-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[backstage/backstage-sa]" \
  --role="roles/iam.workloadIdentityUser"
```

### Update app-config.production.yaml

Configure Backstage for production with PostgreSQL and the correct base URL:

```yaml
# app-config.production.yaml

app:
  baseUrl: http://backstage.example.com

backend:
  baseUrl: http://backstage.example.com
  listen:
    port: 7007
  database:
    client: pg
    connection:
      host: ${POSTGRES_HOST}
      port: ${POSTGRES_PORT}
      user: ${POSTGRES_USER}
      password: ${POSTGRES_PASSWORD}

integrations:
  gitlab:
    - host: gitlab.com
      token: ${GITLAB_TOKEN}
      apiBaseUrl: https://gitlab.com/api/v4
```

### Expose with Ingress (Optional)

To access Backstage externally:

```yaml
# k8s/ingress.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage
  namespace: backstage
  annotations:
    kubernetes.io/ingress.class: gce
spec:
  rules:
    - host: backstage.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backstage
                port:
                  number: 80
```

### Deploy Everything

```bash
# Apply all manifests
kubectl apply -f k8s/backstage-sa.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/backstage.yaml

# Wait for pods to be ready
kubectl wait --namespace backstage \
  --for=condition=Ready pod \
  -l app=postgres \
  --timeout=120s

kubectl wait --namespace backstage \
  --for=condition=Ready pod \
  -l app=backstage \
  --timeout=120s

# Check status
kubectl get pods -n backstage
```

### Verify the Deployment

```bash
# Check pod status
kubectl get pods -n backstage

# View logs
kubectl logs -n backstage -l app=backstage -f

# Port-forward for quick access (before setting up Ingress)
kubectl port-forward -n backstage svc/backstage 7007:80
```

Open http://localhost:7007 to verify Backstage is running in GKE.

### Kubernetes Deployment Summary

```
backstage namespace
├── backstage-sa          (ServiceAccount with Workload Identity)
├── backstage-secrets     (Secret: GITLAB_TOKEN, GITHUB_TOKEN, POSTGRES_PASSWORD)
├── postgres              (Deployment + Service + PVC)
├── backstage             (Deployment + Service)
└── ingress (optional)    (External access)

argocd namespace
├── gitlab-repo-creds     (Secret: ArgoCD repo credentials for GitLab)
```

## Troubleshooting

### Error: GITLAB_TOKEN not set

```bash
# Verify the variable is set
echo $GITLAB_TOKEN

# If empty, set it again
export GITLAB_TOKEN='glpat-YOUR_TOKEN'
```

### Error: Unable to connect to GitLab

1. Verify your token has the correct scopes
2. Check the `apiBaseUrl` in app-config.yaml
3. For self-hosted GitLab, update `host` and `apiBaseUrl` accordingly

### Port 3000 already in use

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9

# Or use a different port
PORT=3001 yarn dev
```

### Kubernetes: Backstage CrashLoopBackOff

```bash
# Check logs for errors
kubectl logs -n backstage -l app=backstage --previous

# Common causes:
# 1. backstage-secrets missing or incomplete - verify with:
kubectl get secret backstage-secrets -n backstage -o yaml
# Ensure GITLAB_TOKEN, GITHUB_TOKEN, and POSTGRES_PASSWORD keys all exist

# 2. PostgreSQL not ready - check:
kubectl get pods -n backstage -l app=postgres

# 3. Wrong image - verify:
kubectl describe deployment backstage -n backstage | grep Image
```

### Kubernetes: Cannot pull image

```bash
# If using GCR, ensure the node service account has access:
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[backstage/backstage-sa]" \
  --role="roles/artifactregistry.reader"
```

## Next Step

Proceed to [Phase 2: Blueprint Creation](03-blueprint-creation.md)
