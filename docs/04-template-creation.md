# Phase 3: The Backstage Template (The Form)

This phase creates the UI definition that gathers user input and orchestrates the scaffolding process.

## Template File

Create the main template definition:

**File:** `packages/backend/templates/genai-gitlab-blueprint/template.yaml`

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: genai-gitlab-template
  title: 🧠 GenAI RAG Application (GitLab)
  description: |
    Provision a secured Vertex AI environment with:
    - GCS Storage Bucket for data
    - Vertex AI API enabled
    - Service Account with proper IAM
    - Streamlit chatbot UI
  tags:
    - gcp
    - vertex-ai
    - gitlab
    - python
    - genai
spec:
  owner: platform-team
  type: service

  # ============================================
  # UI CONFIGURATION - Form fields for users
  # ============================================
  parameters:
    - title: Application Metadata
      required:
        - component_id
        - description
        - owner
      properties:
        component_id:
          title: Service Name
          type: string
          description: Unique identifier for your service (e.g., 'forecasting-bot-v1')
          pattern: '^[a-z0-9-]+$'
          ui:field: EntityNamePicker
          ui:autofocus: true
        description:
          title: Description
          type: string
          description: Brief description of what this GenAI service does
          default: A new GenAI experiment
        owner:
          title: Owner
          type: string
          description: Team or user responsible for this service
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: Group

    - title: Infrastructure Configuration
      required:
        - gcp_project_id
        - gcp_region
      properties:
        gcp_project_id:
          title: Google Cloud Project ID
          type: string
          description: The GCP project where resources will be created and billed
        gcp_region:
          title: GCP Region
          type: string
          description: Region for Vertex AI resources
          default: us-central1
          enum:
            - us-central1
            - us-east1
            - us-west1
            - europe-west1
            - europe-west4
            - asia-northeast1
          enumNames:
            - US Central (Iowa)
            - US East (South Carolina)
            - US West (Oregon)
            - Europe West (Belgium)
            - Europe West (Netherlands)
            - Asia Northeast (Tokyo)
        environment:
          title: Environment
          type: string
          description: Deployment environment
          default: development
          enum:
            - development
            - staging
            - production

    - title: Repository Configuration
      required:
        - repoOwner
      properties:
        repoOwner:
          title: GitLab Group/User
          type: string
          description: The GitLab namespace where the repository will be created
        repoVisibility:
          title: Repository Visibility
          type: string
          default: private
          enum:
            - private
            - internal
            - public

  # ============================================
  # ORCHESTRATION STEPS - What happens on submit
  # ============================================
  steps:
    # Step 1: Copy and process template files
    - id: fetch-base
      name: 📂 Fetching Blueprint
      action: fetch:template
      input:
        url: ./
        copyWithoutTemplating:
          - '**/*.png'
          - '**/*.ico'
        values:
          component_id: ${{ parameters.component_id }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          gcp_project_id: ${{ parameters.gcp_project_id }}
          gcp_region: ${{ parameters.gcp_region }}
          environment: ${{ parameters.environment }}
          repoOwner: ${{ parameters.repoOwner }}

    # Step 2: Publish to GitLab
    - id: publish
      name: 🚀 Publishing to GitLab
      action: publish:gitlab
      input:
        allowedHosts:
          - gitlab.com
        description: ${{ parameters.description }}
        repoUrl: gitlab.com?owner=${{ parameters.repoOwner }}&repo=${{ parameters.component_id }}
        defaultBranch: main
        repoVisibility: ${{ parameters.repoVisibility }}

    # Step 3: Register in Backstage catalog
    - id: register
      name: 📝 Registering in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  # ============================================
  # OUTPUT LINKS - Shown after completion
  # ============================================
  output:
    links:
      - title: 🦊 Source Code Repository
        url: ${{ steps['publish'].output.remoteUrl }}
      - title: 🟧 Open in Catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
      - title: ☁️ GCP Console
        url: https://console.cloud.google.com/home/dashboard?project=${{ parameters.gcp_project_id }}
      - title: 🤖 Vertex AI Console
        url: https://console.cloud.google.com/vertex-ai?project=${{ parameters.gcp_project_id }}
    text:
      - title: Next Steps
        content: |
          ## Your GenAI service has been created!

          1. **Clone the repository:**
             ```
             git clone ${{ steps['publish'].output.remoteUrl }}
             ```

          2. **Deploy infrastructure:**
             Apply the KRM manifests to your Config Connector-enabled cluster:
             ```
             kubectl apply -f infra/
             ```

          3. **Run locally:**
             ```
             cd src && pip install -r requirements.txt && streamlit run app.py
             ```
```

## Template Structure Explanation

### Parameters Section

The `parameters` section defines the form fields users fill out:

| Parameter | Type | Purpose |
|-----------|------|---------|
| `component_id` | EntityNamePicker | Ensures unique, valid service names |
| `description` | string | Free-text description |
| `owner` | OwnerPicker | Selects from registered teams |
| `gcp_project_id` | string | GCP billing project |
| `gcp_region` | enum | Dropdown of supported regions |
| `environment` | enum | dev/staging/prod |
| `repoOwner` | string | GitLab namespace |

### Steps Section

The `steps` section defines the automation workflow:

1. **fetch:template** - Copies blueprint files and replaces placeholders
2. **publish:gitlab** - Creates the GitLab repository
3. **catalog:register** - Registers the new service in Backstage

### Output Section

The `output` section provides helpful links after completion.

## Advanced: Adding Conditional Steps

You can add conditional logic based on user input:

```yaml
steps:
  - id: create-ci-pipeline
    name: 🔧 Setting up CI/CD
    if: ${{ parameters.enableCI === true }}
    action: fetch:template
    input:
      url: ./ci-templates
      targetPath: .gitlab-ci.yml
```

## Advanced: Multi-Step Forms

Split complex forms across multiple pages:

```yaml
parameters:
  - title: Step 1 - Basic Info
    properties:
      # ... fields

  - title: Step 2 - Infrastructure
    properties:
      # ... fields

  - title: Step 3 - Review
    properties:
      # ... review fields
```

## Next Step

Proceed to [Phase 4: Registration & Launch](05-registration-launch.md)
