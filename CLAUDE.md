# Claude Contextual Memory: GenAI Golden Path Tutorial

This document provides context about the GenAI Golden Path Tutorial project to help maintain consistency and understanding across development sessions.

## Project Overview

**Purpose**: A tutorial that teaches how to build a self-service AI platform using Backstage and GitLab, implementing the "Golden Path" strategy for AI engineers and data scientists to provision secure, compliant GenAI environments with a single click.

**Target Users**: Platform Engineers and DevOps teams who want to enable AI engineers with self-service infrastructure provisioning.

**Core Value Proposition**: Transforms infrastructure provisioning from manual, error-prone processes to declarative, automated workflows using GitOps principles.

## Architecture: Three-Layer Model

```
INTERFACE (Backstage) → SOURCE OF TRUTH (GitLab) → ENGINE (Kubernetes + Config Connector)
```

### 1. Interface Layer: Backstage
- Web UI where users fill forms
- Scaffolds infrastructure-as-code (IaC) files
- Registers services in catalog
- Provides developer portal experience

### 2. Source of Truth Layer: GitLab
- Stores Kubernetes Resource Model (KRM) YAML files
- GitOps repository for declarative infrastructure
- Version control and audit trail
- Triggers deployment pipelines

### 3. Engine Layer: GKE + Config Connector
- **GKE Autopilot**: Managed Kubernetes cluster (europe-west1)
- **Config Connector**: Google's Kubernetes operator that converts YAML manifests into actual GCP resources
- Reconciliation loop: Monitors GitLab, creates/updates GCP resources
- Declarative infrastructure management

## Technology Stack

### Core Technologies
- **Backstage**: Open-source developer portal (Spotify)
- **GitLab**: Source control and GitOps
- **GKE Autopilot**: Fully managed Kubernetes
- **Config Connector**: GCP infrastructure as Kubernetes resources
- **Google Cloud Platform**: Cloud provider

### Languages & Tools
- Node.js (v22/v24 — see `engines` in package.json)
- Yarn 4.4.1 (via corepack, see `packageManager` in package.json)
- Docker
- kubectl
- gcloud CLI
- Bash scripting

### Infrastructure Components Provisioned
- GCS Storage Buckets (data lakes)
- Vertex AI API (GenAI services)
- Streamlit Python apps (GenAI chatbots)
- Service catalog entries

## Project Structure

```
backstage-gcp-goldenpath/
├── CLAUDE.md                       # Project context for Claude Code
├── .env.example                    # Environment variable template
├── .gitignore
├── README.md
├── docs/                           # Tutorial documentation
│   ├── 00-architecture.md          # Architecture overview
│   ├── 01-prerequisites.md         # Setup requirements (GKE, kubectl, tools)
│   ├── 02-backstage-setup.md       # Backstage installation & K8s deployment
│   ├── 03-blueprint-creation.md    # Define infrastructure blueprint
│   ├── 04-template-creation.md     # Create Backstage template
│   ├── 05-registration-launch.md   # Register and launch
│   ├── 06-deployment-strategy.md   # GitOps deployment
│   └── 07-plugin-customization.md  # Plugin customization
├── genai-platform/                 # Backstage app (git submodule)
│   ├── packages/
│   │   ├── app/                    # Frontend React app
│   │   └── backend/                # Backend Node.js app
│   ├── package.json
│   ├── tsconfig.json
│   └── yarn.lock
├── img/                            # Documentation images
├── k8s/                            # Kubernetes manifests
│   ├── argocd-appset.yaml
│   ├── backstage.yaml
│   └── secret.yaml
├── scripts/                        # Automation scripts
│   ├── build-and-push.sh           # Build & push Docker image to GHCR
│   ├── check-prerequisites.sh
│   └── setup-gke-config-connector.sh
└── templates/                      # Backstage scaffolder templates
    └── genai-gitlab-blueprint/
```

## Key Concepts

### Golden Path Strategy
A pre-paved, opinionated path for common tasks that:
- Enforces best practices and security policies
- Reduces cognitive load on users
- Maintains compliance and governance
- Enables self-service without sacrificing control

### Infrastructure as Code (IaC) with KRM
- **KRM**: Kubernetes Resource Model - declarative YAML format
- Config Connector translates Kubernetes manifests into GCP API calls
- Example: `StorageBucket` resource → actual GCS bucket

### GitOps Workflow
1. User fills Backstage form
2. Backstage generates KRM YAML files
3. Files committed to GitLab repository
4. Config Connector watches GitLab
5. Config Connector creates/updates GCP resources
6. Kubernetes reconciles desired state with actual state

## GKE Configuration Details

### Cluster Specifications
- **Name**: `golden-path-cluster`
- **Type**: GKE Autopilot (not Standard)
- **Region**: `europe-west1` (regional for HA)
- **Project Variable**: `${GCP_PROJECT_ID}`

### Why Autopilot?
- **Cost**: Pay-per-pod, scale-to-zero, no over-provisioning
- **Operations**: Fully managed nodes, auto-repair, auto-upgrade
- **Security**: Workload Identity by default, shielded nodes, enforced pod security

### Config Connector Setup
- **Mode**: Cluster mode (single installation for all namespaces)
- **Service Account**: `config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com`
- **Permissions**: `storage.admin`, `aiplatform.admin`, `serviceusage.serviceUsageAdmin`
- **Workload Identity**: Enabled for secure GCP authentication

### kubeconfig Context
- **Current context format**: `gke_<project-id>_europe-west1_golden-path-cluster`
- **Config file**: `~/.kube/config`
- **Verification**: `kubectl cluster-info`, `kubectl get nodes`

## Important Environment Variables

```bash
GCP_PROJECT_ID          # GCP project identifier
GITLAB_TOKEN            # GitLab Personal Access Token (glpat-*)
GITHUB_TOKEN            # GitHub Personal Access Token (for reading catalog templates)
POSTGRES_PASSWORD       # PostgreSQL database password for Backstage
```

## Common Commands Reference

### GKE & kubectl
```bash
# Get cluster credentials
gcloud container clusters get-credentials golden-path-cluster \
  --region europe-west1 --project=${GCP_PROJECT_ID}

# Verify kubeconfig
kubectl config current-context
kubectl cluster-info

# Check Config Connector
kubectl wait -n cnrm-system --for=condition=Ready pod \
  -l cnrm.cloud.google.com/component=cnrm-controller-manager
```

### Backstage
```bash
# Create new app
npx @backstage/create-app@latest

# Development mode
yarn install && yarn dev

# Build backend (for Docker image)
yarn install --immutable && yarn build:backend
```

### Build Notes
- **Do NOT run `yarn tsc` as a standalone step** before building. Several dependencies
  (`@azure/msal-common`, `@azure/msal-node`, `@rjsf/core`) ship raw `.ts` source files
  instead of compiled `.d.ts` declarations. With `moduleResolution: "bundler"`, TypeScript
  resolves to these source files and fails type-checking them. `skipLibCheck` only skips
  `.d.ts` files, not `.ts` source files, so it does not help.
- `yarn build:backend` (via `backstage-cli package build`) handles its own TypeScript
  compilation internally and builds successfully.
- The `scripts/build-and-push.sh` script runs `yarn install --immutable` followed by
  `yarn build:backend` directly, skipping the standalone `tsc` step.

## Tutorial Flow Phases

1. **Prerequisites**: Install tools, create GKE cluster, configure Config Connector
2. **Backstage Setup**: Scaffold app, configure GitLab integration
3. **Blueprint Creation**: Define infrastructure components as KRM YAML
4. **Template Creation**: Build Backstage template with parameterized inputs
5. **Registration & Launch**: Register template, execute golden path
6. **Deployment Strategy**: GitOps reconciliation and resource creation

## Development Guidelines

### When Editing Documentation
- Maintain consistency with existing tutorial structure
- Use code blocks with bash syntax highlighting
- Include verification steps after each major action
- Explain WHY, not just HOW (especially for architectural decisions)
- Keep commands copy-pasteable with proper variable substitution

### When Working with Templates
- Templates use Jinja-style templating: `${{ parameters.projectName }}`
- KRM YAML files must be valid Kubernetes manifests
- Always include metadata annotations for Config Connector
- The `publish:gitlab` scaffolder action does **not** support `allowedHosts` or `description`
  input properties (those belong to `publish:github`). Using them causes an `InputError` at
  runtime. Only pass supported inputs: `repoUrl`, `defaultBranch`, `repoVisibility`, etc.

### When Troubleshooting
- Check kubeconfig context first: `kubectl config current-context`
- Verify Config Connector pods: `kubectl get pods -n cnrm-system`
- Check GCP permissions for service account
- Review GitLab token scopes: `api`, `read_user`, `write_repository`

## File Naming Conventions

- Documentation: `##-descriptive-name.md` (numbered sequentially)
- Scripts: `kebab-case.sh`
- Templates: `template.yaml` (standard Backstage convention)
- Infrastructure: `resource-type.yaml` (e.g., `storage.yaml`, `vertex.yaml`)

## Best Practices for This Tutorial

### GKE Autopilot
- Always define resource requests and limits
- Use namespaces for environment isolation (dev, staging, prod)
- Leverage Vertical Pod Autoscaler (VPA) for optimization
- Regional clusters for high availability

### Config Connector
- One KRM file per resource type
- Include proper annotations for project/region
- Test resources in isolation before combining
- Use `kubectl describe` to debug reconciliation issues

### GitOps
- Commit infrastructure changes to GitLab, not manual GCP Console edits
- Use meaningful commit messages
- Tag releases for reproducibility
- Keep sensitive data in secrets, not YAML

## Security Considerations

- **Workload Identity**: Preferred over service account keys
- **GitLab Tokens**: Store securely, rotate regularly, use minimal scopes
- **GCP Permissions**: Principle of least privilege for Config Connector SA
- **Secrets Management**: Never commit tokens or keys to Git
- **Pod Security**: Autopilot enforces security contexts automatically

## Success Metrics

A successful implementation enables:
- Data Scientists to provision GenAI environments in < 5 minutes
- Zero manual GCP Console operations
- 100% infrastructure under version control
- Audit trail for all infrastructure changes
- Repeatable, consistent environment provisioning

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| kubectl auth errors | Refresh credentials: `gcloud container clusters get-credentials` |
| Config Connector not reconciling | Check SA permissions and Workload Identity binding |
| GitLab integration failing | Verify `GITLAB_TOKEN` is set and has correct scopes |
| Resource creation stuck | Check Config Connector logs: `kubectl logs -n cnrm-system` |
| Context not found | Verify cluster exists: `gcloud container clusters list` |
| `publish:gitlab` InputError (allowedHosts/description) | Remove unsupported properties; use only `repoUrl`, `defaultBranch`, `repoVisibility` |
| GitHub 401 reading template from catalog | Ensure `GITHUB_TOKEN` exists in `backstage-secrets` K8s secret (`k8s/secret.yaml`) and restart the pod |

## Related Resources

- [Backstage Documentation](https://backstage.io/docs)
- [Config Connector Reference](https://cloud.google.com/config-connector/docs)
- [GKE Autopilot Best Practices](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [GitLab API Documentation](https://docs.gitlab.com/ee/api/)

## Notes for Future Development

- Consider adding ArgoCD for advanced GitOps capabilities
- Explore Backstage plugins for observability (e.g., Datadog, Grafana)
- Implement multi-environment support (dev/staging/prod)
- Add cost monitoring dashboards
- Integrate with organizational SSO (OIDC/SAML)

---

**Last Updated**: 2026-02-10
**Cluster Region**: europe-west1
**GCP Project Pattern**: `project-*` or `${GCP_PROJECT_ID}`