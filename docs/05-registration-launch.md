# Phase 4: Registration & Launch

This phase registers your template with Backstage and launches the platform.

## Step 4.1: Register the Template

Open `app-config.yaml` and add your template to the catalog locations:

```yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    # Existing default locations...
    - type: file
      target: ../../examples/entities.yaml

    # Add your Golden Path template
    - type: file
      target: ./packages/backend/templates/genai-gitlab-blueprint/template.yaml
      rules:
        - allow: [Template]
```

## Step 4.2: Configure Required Plugins (if not already done)

Ensure the GitLab scaffolder is properly configured in `packages/backend/src/index.ts`:

```typescript
import { createBackend } from '@backstage/backend-defaults';

const backend = createBackend();

// Core plugins
backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-proxy-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-techdocs-backend'));

// Scaffolder modules
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitlab'));

// Catalog
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'));

// Auth
backend.add(import('@backstage/plugin-auth-backend'));
backend.add(import('@backstage/plugin-auth-backend-module-guest-provider'));

backend.start();
```

## Step 4.3: Start the Platform

From the root folder of your Backstage app:

```bash
# Install dependencies (if not done)
yarn install

# Start development server
yarn start
```

This starts:
- Frontend at http://localhost:3000
- Backend at http://localhost:7007

## Step 4.4: Execute the Golden Path

### Navigate to the Template

1. Open your browser to **http://localhost:3000**
2. Click **Create** in the left sidebar
3. Find the card: **"🧠 GenAI RAG Application (GitLab)"**
4. Click **Choose**

### Fill in the Form

**Application Metadata:**
| Field | Example Value |
|-------|---------------|
| Service Name | `compliance-bot-v1` |
| Description | `AI agent for checking policy documents` |
| Owner | `data-science-team` |

**Infrastructure Configuration:**
| Field | Example Value |
|-------|---------------|
| GCP Project ID | `my-genai-project-123` |
| GCP Region | `us-central1` |
| Environment | `development` |

**Repository Configuration:**
| Field | Example Value |
|-------|---------------|
| GitLab Group/User | `your-gitlab-username` |
| Visibility | `private` |

### Submit and Monitor

1. Click **Next** to review
2. Click **Create** to execute
3. Watch the progress as each step completes:
   - ✅ Fetching Blueprint
   - ✅ Publishing to GitLab
   - ✅ Registering in Catalog

### Verify Results

After completion, you'll see output links:
- **Source Code Repository** - Opens your new GitLab repo
- **Open in Catalog** - Shows the service in Backstage
- **GCP Console** - Direct link to your GCP project
- **Vertex AI Console** - Direct link to Vertex AI

## Step 4.5: Verify the Created Repository

Check your GitLab repository contains:

```
compliance-bot-v1/
├── catalog-info.yaml      # Backstage metadata
├── Dockerfile             # Container definition
├── infra/
│   ├── storage.yaml       # GCS bucket (with your project ID)
│   ├── vertex.yaml        # Vertex AI enablement
│   └── iam.yaml           # Service account & IAM
└── src/
    ├── app.py             # Streamlit app (with your config)
    └── requirements.txt   # Python dependencies
```

All placeholders should be replaced with your actual values.

## Troubleshooting

### Template not appearing

```bash
# Check for YAML syntax errors
yarn backstage-cli config:check

# Verify file location matches app-config.yaml
ls -la packages/backend/templates/genai-gitlab-blueprint/template.yaml
```

### GitLab publish fails

1. Verify `GITLAB_TOKEN` is set and has correct scopes
2. Check the token hasn't expired
3. Ensure the GitLab user/group exists

```bash
# Test GitLab token
curl --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://gitlab.com/api/v4/user"
```

### Catalog registration fails

The catalog needs the repository to be accessible. Ensure:
1. Repository was created successfully
2. `catalog-info.yaml` exists at the root
3. GitLab integration is configured in `app-config.yaml`

### "Entity already exists" error

The service name must be unique. Either:
- Choose a different name
- Delete the existing entity from the catalog first

## Next Step

Proceed to [Phase 5: Deployment Strategy](06-deployment-strategy.md) to learn how to automatically deploy the infrastructure.
