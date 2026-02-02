# Architecture Overview

This document describes the architecture of the GenAI Golden Path platform, showing how Backstage, GitLab, ArgoCD, and Google Cloud work together to provide a self-service developer experience.

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Component Flow](#component-flow)
- [Sequence Diagram](#sequence-diagram)
- [Permission Model](#permission-model)
- [Technology Stack](#technology-stack)

## High-Level Architecture

The platform follows a **GitOps** pattern where:
1. Developers interact with Backstage UI (self-service portal)
2. Backstage generates code and pushes to GitLab (source of truth)
3. ArgoCD syncs GitLab to Kubernetes (continuous deployment)
4. Config Connector creates GCP resources (infrastructure as code)

```mermaid
flowchart TB
    subgraph User["👤 Developer Experience"]
        U[Developer] --> |"1. Fills form"| BSU[Backstage UI]
        BSU --> |"Selects template"| TPL[GenAI Golden Path Template]
    end

    subgraph Backstage["🎭 Backstage Platform"]
        TPL --> |"2. Scaffolder processes"| SCF[Scaffolder Engine]
        SCF --> |"Replaces placeholders"| VAL["Template Values<br/>• component_id<br/>• gcp_project_id<br/>• owner"]
        VAL --> |"3. Generates files"| GEN["Generated Files<br/>├── infra/<br/>│   ├── iam.yaml<br/>│   ├── storage.yaml<br/>│   └── vertex.yaml<br/>├── src/<br/>│   └── app.py<br/>├── Dockerfile<br/>└── catalog-info.yaml"]
    end

    subgraph GitLab["🦊 GitLab"]
        GEN --> |"4. publish:gitlab action"| REPO[New Repository]
        REPO --> |"Contains"| INFRA["infra/*.yaml<br/>(KRM Manifests)"]
        REPO --> |"Contains"| SRC["src/<br/>(Application Code)"]
        REPO --> |"Contains"| CAT["catalog-info.yaml"]
    end

    subgraph ArgoCDSystem["🔄 ArgoCD"]
        REPO -.-> |"5. Watches repo"| ARGO[ArgoCD Controller]
        ARGO --> |"6. Detects changes"| SYNC[Sync Process]
        SYNC --> |"7. Applies manifests"| APPLY["kubectl apply"]
    end

    subgraph GKE["☸️ GKE Autopilot Cluster"]
        APPLY --> |"8. Creates CRDs"| CC[Config Connector]

        subgraph ConfigConnector["Config Connector Resources"]
            CC --> IAM_SA["IAMServiceAccount<br/>genai-project-sa"]
            CC --> BUCKET["StorageBucket<br/>genai-project-data"]
            CC --> SVC["Service<br/>aiplatform.googleapis.com"]
            CC --> IAM_POL1["IAMPolicyMember<br/>storage-access"]
            CC --> IAM_POL2["IAMPolicyMember<br/>vertex-access"]
        end

        subgraph WorkloadIdentity["🔐 Workload Identity"]
            CC_SA["Config Connector SA<br/>(K8s)"] --> |"Impersonates"| GCP_SA["config-connector-sa<br/>(GCP)"]
        end
    end

    subgraph GCP["☁️ Google Cloud Platform"]
        subgraph IAM["IAM"]
            GCP_SA --> |"9. Creates"| SA_REAL["Service Account<br/>genai-project-sa@project.iam"]
            SA_REAL --> |"Granted"| ROLE1["roles/storage.objectUser"]
            SA_REAL --> |"Granted"| ROLE2["roles/aiplatform.user"]
        end

        subgraph Storage["Cloud Storage"]
            BUCKET --> |"10. Creates"| GCS["GCS Bucket<br/>genai-project-data"]
        end

        subgraph VertexAI["Vertex AI"]
            SVC --> |"11. Enables"| API["aiplatform.googleapis.com"]
        end
    end

    subgraph Catalog["📚 Backstage Catalog"]
        CAT --> |"12. catalog:register"| REG[Register Component]
        REG --> |"Appears in"| CATALOG["Service Catalog<br/>• Component view<br/>• Resource dependencies<br/>• GCP Console links"]
    end

    classDef user fill:#e1f5fe,stroke:#01579b
    classDef backstage fill:#fff3e0,stroke:#e65100
    classDef gitlab fill:#fce4ec,stroke:#880e4f
    classDef argocd fill:#f3e5f5,stroke:#4a148c
    classDef gke fill:#e8f5e9,stroke:#1b5e20
    classDef gcp fill:#e3f2fd,stroke:#0d47a1
    classDef catalog fill:#fff8e1,stroke:#ff6f00

    class U,BSU,TPL user
    class SCF,VAL,GEN backstage
    class REPO,INFRA,SRC,CAT gitlab
    class ARGO,SYNC,APPLY argocd
    class CC,IAM_SA,BUCKET,SVC,IAM_POL1,IAM_POL2,CC_SA,GCP_SA gke
    class SA_REAL,ROLE1,ROLE2,GCS,API gcp
    class REG,CATALOG catalog
```

## Component Flow

### Step-by-Step Breakdown

| Step | Component | Action | Output |
|------|-----------|--------|--------|
| 1 | Developer | Fills Backstage form | Form data (component_id, project, etc.) |
| 2 | Scaffolder | Processes template | Replaces `${{ values.* }}` placeholders |
| 3 | Scaffolder | Generates files | Complete project structure |
| 4 | GitLab Action | Creates repository | New repo with all files |
| 5 | ArgoCD | Watches repository | Detects new/changed files |
| 6 | ArgoCD | Syncs to cluster | Applies Kubernetes manifests |
| 7 | Config Connector | Reconciles CRDs | Creates GCP API requests |
| 8-11 | GCP | Provisions resources | SA, Bucket, API, IAM bindings |
| 12 | Catalog | Registers component | Visible in Backstage UI |

## Sequence Diagram

This diagram shows the temporal flow of events from developer action to resource creation:

```mermaid
sequenceDiagram
    autonumber
    participant Dev as 👤 Developer
    participant BS as 🎭 Backstage
    participant GL as 🦊 GitLab
    participant Argo as 🔄 ArgoCD
    participant K8s as ☸️ GKE
    participant CC as ⚙️ Config Connector
    participant GCP as ☁️ GCP

    Dev->>BS: Open Software Catalog
    Dev->>BS: Select "GenAI Golden Path" template
    Dev->>BS: Fill form (name, project, region)

    rect rgb(255, 243, 224)
        Note over BS: Scaffolder Processing
        BS->>BS: Load template.yaml
        BS->>BS: Replace ${{ values.* }} placeholders
        BS->>BS: Generate infra/*.yaml, src/*, Dockerfile
    end

    BS->>GL: publish:gitlab action
    GL-->>GL: Create repository
    GL-->>GL: Push generated files
    GL-->>BS: Return repo URL

    BS->>BS: catalog:register action
    BS-->>Dev: Show success + links

    rect rgb(243, 229, 245)
        Note over Argo: GitOps Sync Loop
        loop Every 3 minutes (or webhook)
            Argo->>GL: Poll for changes
            GL-->>Argo: New commit detected
        end
    end

    Argo->>K8s: Apply infra/*.yaml manifests

    rect rgb(232, 245, 233)
        Note over CC: Config Connector Reconciliation
        K8s->>CC: IAMServiceAccount CR created
        K8s->>CC: StorageBucket CR created
        K8s->>CC: Service CR created
        K8s->>CC: IAMPolicyMember CRs created
    end

    rect rgb(227, 242, 253)
        Note over GCP: GCP Resource Creation
        CC->>GCP: Create Service Account
        GCP-->>CC: SA created ✓
        CC->>GCP: Create GCS Bucket
        GCP-->>CC: Bucket created ✓
        CC->>GCP: Enable Vertex AI API
        GCP-->>CC: API enabled ✓
        CC->>GCP: Bind IAM roles
        GCP-->>CC: Roles bound ✓
    end

    CC-->>K8s: Update CR status: Ready
    K8s-->>Argo: Resources synced
    Argo-->>Argo: Mark app as "Synced" ✓

    Dev->>BS: View in Catalog
    BS-->>Dev: Show component + GCP links
```

## Permission Model

Config Connector uses **Workload Identity** to authenticate with GCP without managing service account keys.

### Workload Identity Flow

```mermaid
flowchart LR
    subgraph GKE["GKE Cluster"]
        subgraph CNRM["cnrm-system namespace"]
            POD["Config Connector Pod"]
            KSA["K8s Service Account<br/>cnrm-controller-manager"]
        end
        POD --> KSA
    end

    subgraph GCP["Google Cloud"]
        GSA["GCP Service Account<br/>config-connector-sa@project.iam"]

        subgraph Permissions
            R1["roles/storage.admin"]
            R2["roles/aiplatform.admin"]
            R3["roles/serviceusage.serviceUsageAdmin"]
            R4["roles/iam.serviceAccountAdmin"]
            R5["roles/resourcemanager.projectIamAdmin"]
        end

        GSA --> R1
        GSA --> R2
        GSA --> R3
        GSA --> R4
        GSA --> R5
    end

    KSA <--> |"Workload Identity<br/>Federation"| GSA

    style KSA fill:#c8e6c9
    style GSA fill:#bbdefb
```

### Required IAM Roles

| Role | Purpose | Used By |
|------|---------|---------|
| `roles/storage.admin` | Create and manage GCS buckets | StorageBucket CR |
| `roles/aiplatform.admin` | Manage Vertex AI resources | Service CR |
| `roles/serviceusage.serviceUsageAdmin` | Enable/disable GCP APIs | Service CR |
| `roles/iam.serviceAccountAdmin` | Create service accounts | IAMServiceAccount CR |
| `roles/resourcemanager.projectIamAdmin` | Manage project IAM policies | IAMPolicyMember CR |

### Template to Permission Mapping

```mermaid
flowchart LR
    subgraph Templates["📁 Template Files"]
        T1["template.yaml<br/><i>Backstage UI definition</i>"]
        T2["infra/iam.yaml<br/><i>Service Account + IAM</i>"]
        T3["infra/storage.yaml<br/><i>GCS Bucket</i>"]
        T4["infra/vertex.yaml<br/><i>API enablement</i>"]
        T5["catalog-info.yaml<br/><i>Backstage registration</i>"]
    end

    subgraph Permissions["🔐 Required Permissions"]
        P1["roles/iam.serviceAccountAdmin"]
        P2["roles/resourcemanager.projectIamAdmin"]
        P3["roles/storage.admin"]
        P4["roles/aiplatform.admin"]
        P5["roles/serviceusage.serviceUsageAdmin"]
    end

    subgraph Created["✅ Created Resources"]
        C1["GCP Service Account"]
        C2["GCS Bucket"]
        C3["Vertex AI API"]
        C4["IAM Policy Bindings"]
    end

    T2 --> |"requires"| P1
    T2 --> |"requires"| P2
    T3 --> |"requires"| P3
    T4 --> |"requires"| P4
    T4 --> |"requires"| P5

    P1 --> |"creates"| C1
    P2 --> |"binds"| C4
    P3 --> |"creates"| C2
    P4 --> |"enables"| C3
```

## Technology Stack

### Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Developer Portal | Backstage | Self-service UI, software catalog |
| Source Control | GitLab | Git repository, CI/CD pipelines |
| GitOps Controller | ArgoCD | Continuous deployment, sync management |
| Kubernetes | GKE Autopilot | Container orchestration, managed nodes |
| Infrastructure as Code | Config Connector | GCP resource management via K8s CRDs |
| Cloud Provider | Google Cloud | Compute, storage, AI/ML services |

### Data Flow Summary

```mermaid
flowchart LR
    A[Developer] -->|"Self-Service"| B[Backstage]
    B -->|"GitOps"| C[GitLab]
    C -->|"Continuous Sync"| D[ArgoCD]
    D -->|"Declarative Config"| E[GKE + Config Connector]
    E -->|"API Calls"| F[GCP Resources]

    style A fill:#e3f2fd
    style B fill:#fff3e0
    style C fill:#fce4ec
    style D fill:#f3e5f5
    style E fill:#e8f5e9
    style F fill:#e3f2fd
```

## Key Design Decisions

### Why GitOps?

1. **Single Source of Truth**: All configuration lives in Git
2. **Audit Trail**: Every change is a commit with author and timestamp
3. **Rollback**: Easy to revert to any previous state
4. **Security**: No direct access to production clusters needed

### Why Config Connector?

1. **Kubernetes-Native**: Manage GCP resources using familiar `kubectl` commands
2. **Declarative**: Define desired state, let the system reconcile
3. **Unified Tooling**: Same workflow for app deployments and infrastructure
4. **Drift Detection**: Automatically corrects manual changes in GCP

### Why Workload Identity?

1. **No Key Management**: No service account keys to rotate or secure
2. **Least Privilege**: Fine-grained permissions per workload
3. **Automatic Rotation**: Credentials are short-lived and auto-refreshed
4. **Audit Logging**: All API calls are traceable to specific pods

## Next Steps

- [Prerequisites](01-prerequisites.md) - Set up your environment
- [Backstage Setup](02-backstage-setup.md) - Configure the developer portal
- [Blueprint Creation](03-blueprint-creation.md) - Create template files
- [Template Creation](04-template-creation.md) - Define the Backstage template