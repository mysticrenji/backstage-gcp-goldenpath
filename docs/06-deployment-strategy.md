# Phase 5: Deployment Strategy (GitOps)

This phase completes the automation cycle by deploying the generated infrastructure from GitLab to your Kubernetes cluster.

## The GitOps Flow

```
+-------------+     +-------------+     +------------------+     +-------------+
|   GitLab    | --> |  GitLab     | --> |   Kubernetes     | --> |    GCP      |
| Repository  |     |   Agent /   |     |   Cluster with   |     |  Resources  |
|             |     |   ArgoCD    |     | Config Connector |     |             |
+-------------+     +-------------+     +------------------+     +-------------+
                          |
                    Watches for
                    new repos/changes
```

## Option A: GitLab Agent for Kubernetes

The GitLab Agent provides a secure, pull-based connection between GitLab and your cluster.

### Step 1: Register the Agent in GitLab

1. Go to your GitLab group: **Operate > Kubernetes clusters**
2. Click **Connect a cluster**
3. Enter agent name: `golden-path-agent`
4. Create the agent configuration file in your infrastructure repo

### Step 2: Create Agent Configuration

Create `.gitlab/agents/golden-path-agent/config.yaml`:

```yaml
gitops:
  manifest_projects:
    # Watch all projects in the group for infra/ directory
    - id: your-gitlab-group
      default_namespace: default
      paths:
        - glob: '**/infra/*.yaml'
      reconcile_timeout: 3600s
      dry_run_strategy: none
      prune: true
      prune_timeout: 3600s
      prune_propagation_policy: foreground

ci_access:
  groups:
    - id: your-gitlab-group

observability:
  logging:
    level: info
```

### Step 3: Install the Agent on Your Cluster

```bash
# Create namespace
kubectl create namespace gitlab-agent

# Install via Helm
helm repo add gitlab https://charts.gitlab.io
helm repo update

helm upgrade --install golden-path-agent gitlab/gitlab-agent \
  --namespace gitlab-agent \
  --set config.token=<your-agent-token> \
  --set config.kasAddress=wss://kas.gitlab.com
```

### Step 4: Verify Agent Connection

```bash
kubectl get pods -n gitlab-agent
# Should show agent running

# Check agent logs
kubectl logs -n gitlab-agent -l app=gitlab-agent
```

## Option B: ArgoCD

ArgoCD provides more visibility and control over deployments.

### Step 1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

### Step 2: Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open https://localhost:8080 and login with `admin` and the password.

### Step 3: Connect GitLab Repository

```bash
# Add GitLab repository
argocd repo add https://gitlab.com/your-group/compliance-bot-v1.git \
  --username oauth2 \
  --password $GITLAB_TOKEN
```

### Step 4: Create ArgoCD Application

```yaml
# argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: compliance-bot-v1
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://gitlab.com/your-group/compliance-bot-v1.git
    targetRevision: main
    path: infra
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```bash
kubectl apply -f argocd-application.yaml
```

### Step 5: Create ApplicationSet for Auto-Discovery

#### Kuberenets secret creation                                                                                                  
```bash                                                                                                                                        
  kubectl create secret generic gitlab-token -n argocd --from-literal=token=$GITLAB_TOKEN    
```
For automatic detection of new Golden Path repositories:

```yaml
# applicationset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: golden-path-apps
  namespace: argocd
spec:
  generators:
    - scmProvider:
        gitlab:
          group: your-gitlab-group
          includeSubgroups: true
          tokenRef:
            secretName: gitlab-token
            key: token
        filters:
          - pathsExist:
              - infra/storage.yaml
  template:
    metadata:
      name: '{{repository}}'
    spec:
      project: default
      source:
        repoURL: '{{url}}'
        targetRevision: main
        path: infra
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{repository}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

## Verification: End-to-End Flow

After setup, the complete flow works like this:

1. **User Action**: Data Scientist fills form in Backstage
2. **Backstage**: Creates repo in GitLab with IaC files
3. **GitOps Agent**: Detects new repository
4. **Kubernetes**: Agent applies `infra/*.yaml` manifests
5. **Config Connector**: Sees KRM resources, calls GCP APIs
6. **GCP**: Creates actual Storage Bucket, enables Vertex AI

### Verify Resources Were Created

```bash
# Check Config Connector resources
kubectl get storagebuckets
kubectl get services.serviceusage

# Check GCP directly
gcloud storage buckets list | grep compliance-bot
gcloud services list --enabled | grep aiplatform
```

## Policy Enforcement with OPA Gatekeeper

Add policy checks before resources are created:

### Install Gatekeeper

```bash
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
```

### Example: Require Labels

```yaml
# constraint-template.yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          provided := {label | input.review.object.metadata.labels[label]}
          required := {label | label := input.parameters.labels[_]}
          missing := required - provided
          count(missing) > 0
          msg := sprintf("Missing required labels: %v", [missing])
        }
---
# constraint.yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: require-backstage-labels
spec:
  match:
    kinds:
      - apiGroups: ["storage.cnrm.cloud.google.com"]
        kinds: ["StorageBucket"]
  parameters:
    labels:
      - managed-by
      - cost-center
```

This ensures all buckets created via the Golden Path have proper labels.

## Summary

You now have a complete self-service AI platform where:

1. **Data Scientists** use Backstage UI to request resources
2. **GitLab** stores all infrastructure as code
3. **GitOps** automatically deploys changes
4. **Config Connector** provisions actual GCP resources
5. **OPA Gatekeeper** enforces security policies

The entire process is auditable, repeatable, and secure.
