# GenAI Golden Path Tutorial

A step-by-step guide to building a self-service AI platform using Backstage and GitLab. This implements the "Golden Path" strategy where Data Scientists can click a button to provision secure, compliant GenAI environments.

## Architecture Overview

For detailed architecture diagrams and component flows, see [docs/00-architecture.md](docs/00-architecture.md).

```
+-------------------+     +-------------------+     +-------------------+     +-------------------+
|   👤 Developer    |     |  🎭 Backstage     |     |   🦊 GitLab       |     |  🔄 ArgoCD        |
|                   | --> |   (Self-Service)  | --> |  (Source of Truth)| --> |  (GitOps Sync)    |
+-------------------+     +-------------------+     +-------------------+     +-------------------+
                                                                                       |
                                                                                       v
                          +-------------------+     +-------------------+     +-------------------+
                          |   ☁️ GCP          | <-- | ⚙️ Config         | <-- |  ☸️ GKE Autopilot |
                          |  (Real Resources) |     |    Connector      |     |  (Kubernetes)     |
                          +-------------------+     +-------------------+     +-------------------+
```

## What Gets Provisioned

When a user executes the Golden Path:
1. **Storage Bucket** - GCS bucket for data lake
2. **Vertex AI API** - Enabled for the GCP project
3. **Streamlit App** - Python GenAI chatbot skeleton
4. **Catalog Entry** - Service registered in Backstage

## Prerequisites

See [docs/01-prerequisites.md](docs/01-prerequisites.md)

## Tutorial Phases

| Phase | Description | Guide |
|-------|-------------|-------|
| 0 | Architecture Overview | [docs/00-architecture.md](docs/00-architecture.md) |
| 0 | Prerequisites & GKE Setup | [docs/01-prerequisites.md](docs/01-prerequisites.md) |
| 1 | Backstage Installation & Setup | [docs/02-backstage-setup.md](docs/02-backstage-setup.md) |
| 2 | Define the Golden Path Blueprint | [docs/03-blueprint-creation.md](docs/03-blueprint-creation.md) |
| 3 | Create the Backstage Template | [docs/04-template-creation.md](docs/04-template-creation.md) |
| 4 | Registration & Launch | [docs/05-registration-launch.md](docs/05-registration-launch.md) |
| 5 | Deployment Strategy (GitOps) | [docs/06-deployment-strategy.md](docs/06-deployment-strategy.md) |

## Quick Start

```bash
# 1. Install prerequisites
./scripts/check-prerequisites.sh

# 2. Create Backstage app
npx @backstage/create-app@latest

# 3. Copy templates
cp -r templates/* <your-backstage-app>/packages/backend/templates/

# 4. Configure and run
cd <your-backstage-app>
yarn install && yarn dev
```

## Project Structure

```
genai-golden-path-tutorial/
├── README.md                    # This file
├── docs/                        # Step-by-step documentation
│   ├── 00-architecture.md       # Architecture diagrams (Mermaid)
│   ├── 01-prerequisites.md      # GKE, Config Connector, Workload Identity
│   ├── 02-backstage-setup.md
│   ├── 03-blueprint-creation.md
│   ├── 04-template-creation.md
│   ├── 05-registration-launch.md
│   └── 06-deployment-strategy.md
├── genai-platform/              # Backstage application
│   └── packages/backend/templates/
│       └── genai-gitlab-blueprint/
│           ├── template.yaml    # Backstage template definition
│           ├── catalog-info.yaml
│           ├── Dockerfile
│           ├── infra/
│           │   ├── iam.yaml     # Service Account + IAM bindings
│           │   ├── storage.yaml # GCS bucket (KRM)
│           │   └── vertex.yaml  # Vertex AI API enablement
│           └── src/
│               ├── app.py       # Streamlit GenAI app
│               └── requirements.txt
└── scripts/                     # Helper scripts
    ├── check-prerequisites.sh
    └── setup-gke-config-connector.sh
```
