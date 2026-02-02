# Phase 2: Defining the "Golden Path" Blueprint

This phase creates the template files that define what gets generated when a user runs the Golden Path. These files use placeholders (like `${{ values.component_id }}`) that Backstage replaces with user input.

## Directory Structure

Create the template directory structure:

```bash
mkdir -p packages/backend/templates/genai-gitlab-blueprint/{infra,src}
```

## Blueprint Files

### File 1: infra/storage.yaml (The Data Lake)

This KRM (Kubernetes Resource Model) file defines a Google Cloud Storage bucket.

```yaml
# packages/backend/templates/genai-gitlab-blueprint/infra/storage.yaml

apiVersion: storage.cnrm.cloud.google.com/v1beta1
kind: StorageBucket
metadata:
  name: ${{ values.component_id }}-data
  labels:
    managed-by: backstage
    cost-center: ai-research
    environment: ${{ values.environment }}
spec:
  location: EU
  uniformBucketLevelAccess: true
  versioning:
    enabled: true
  lifecycle:
    rule:
      - action:
          type: Delete
        condition:
          age: 365
```

**What this does:**
- Creates a GCS bucket named `<your-app>-data`
- Enables uniform bucket-level access (security best practice)
- Enables versioning for data protection
- Auto-deletes objects older than 365 days

### File 2: infra/vertex.yaml (The Intelligence)

Enables the Vertex AI API for the project.

```yaml
# packages/backend/templates/genai-gitlab-blueprint/infra/vertex.yaml

apiVersion: serviceusage.cnrm.cloud.google.com/v1beta1
kind: Service
metadata:
  name: aiplatform.googleapis.com
  annotations:
    cnrm.cloud.google.com/deletion-policy: "abandon"
spec:
  projectRef:
    external: ${{ values.gcp_project_id }}
```

**What this does:**
- Enables the Vertex AI (aiplatform) API in the specified GCP project
- Uses `abandon` deletion policy so disabling the API doesn't break existing resources

### File 3: infra/iam.yaml (Service Account)

Creates a service account for the GenAI application.

```yaml
# packages/backend/templates/genai-gitlab-blueprint/infra/iam.yaml

apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMServiceAccount
metadata:
  name: ${{ values.component_id }}-sa
spec:
  displayName: "${{ values.component_id }} Service Account"
---
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicyMember
metadata:
  name: ${{ values.component_id }}-storage-access
spec:
  member: serviceAccount:${{ values.component_id }}-sa@${{ values.gcp_project_id }}.iam.gserviceaccount.com
  role: roles/storage.objectUser
  resourceRef:
    kind: StorageBucket
    name: ${{ values.component_id }}-data
---
apiVersion: iam.cnrm.cloud.google.com/v1beta1
kind: IAMPolicyMember
metadata:
  name: ${{ values.component_id }}-vertex-access
spec:
  member: serviceAccount:${{ values.component_id }}-sa@${{ values.gcp_project_id }}.iam.gserviceaccount.com
  role: roles/aiplatform.user
  resourceRef:
    apiVersion: resourcemanager.cnrm.cloud.google.com/v1beta1
    kind: Project
    external: projects/${{ values.gcp_project_id }}
```

### File 4: src/app.py (The Application)

A Python Streamlit application skeleton for a GenAI chatbot.

```python
# packages/backend/templates/genai-gitlab-blueprint/src/app.py

import streamlit as st
import vertexai
from vertexai.generative_models import GenerativeModel, ChatSession

# Configuration
PROJECT_ID = "${{ values.gcp_project_id }}"
REGION = "${{ values.gcp_region }}"
MODEL_ID = "gemini-2.5-flash"

# Page config
st.set_page_config(
    page_title="${{ values.component_id }}",
    page_icon="🤖",
    layout="wide"
)

st.title("🤖 ${{ values.component_id }}")
st.caption("Deployed via the AI Golden Path")

# Initialize Vertex AI
@st.cache_resource
def init_vertex_ai():
    vertexai.init(project=PROJECT_ID, location=REGION)
    return GenerativeModel(MODEL_ID)

# Initialize chat session
@st.cache_resource
def get_chat_session(_model):
    return _model.start_chat()

# Main app
def main():
    # Initialize model
    try:
        model = init_vertex_ai()
        chat = get_chat_session(model)
        st.success("✅ Connected to Vertex AI")
    except Exception as e:
        st.error(f"Failed to initialize Vertex AI: {e}")
        st.info("Make sure you have the correct permissions and the API is enabled.")
        return

    # Chat interface
    if "messages" not in st.session_state:
        st.session_state.messages = []

    # Display chat history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Chat input
    if prompt := st.chat_input("Ask me anything..."):
        # Add user message
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        # Get AI response
        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                response = chat.send_message(prompt)
                st.markdown(response.text)
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": response.text
                })

if __name__ == "__main__":
    main()
```

### File 5: src/requirements.txt

```text
# packages/backend/templates/genai-gitlab-blueprint/src/requirements.txt

streamlit>=1.28.0
google-cloud-aiplatform>=1.38.0
vertexai>=1.38.0
```

### File 6: Dockerfile

```dockerfile
# packages/backend/templates/genai-gitlab-blueprint/Dockerfile

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY src/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ .

# Expose Streamlit port
EXPOSE 8501

# Health check
HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

# Run app
ENTRYPOINT ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

### File 7: catalog-info.yaml (Backstage Metadata)

This registers the created service back into Backstage.

```yaml
# packages/backend/templates/genai-gitlab-blueprint/catalog-info.yaml

apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.component_id }}
  description: ${{ values.description }}
  annotations:
    gitlab.com/project-slug: ${{ values.repoOwner }}/${{ values.component_id }}
    backstage.io/techdocs-ref: dir:.
  tags:
    - genai
    - vertex-ai
    - python
  links:
    - url: https://console.cloud.google.com/vertex-ai?project=${{ values.gcp_project_id }}
      title: Vertex AI Console
      icon: cloud
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
  system: genai-platform
  dependsOn:
    - resource:${{ values.component_id }}-bucket
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: ${{ values.component_id }}-bucket
  description: Data storage bucket for ${{ values.component_id }}
spec:
  type: storage
  owner: ${{ values.owner }}
  system: genai-platform
```

## File Summary

| File | Purpose |
|------|---------|
| `infra/storage.yaml` | Creates GCS bucket for data storage |
| `infra/vertex.yaml` | Enables Vertex AI API |
| `infra/iam.yaml` | Creates service account with proper permissions |
| `src/app.py` | Streamlit GenAI chatbot application |
| `src/requirements.txt` | Python dependencies |
| `Dockerfile` | Container image definition |
| `catalog-info.yaml` | Backstage service catalog metadata |

## Next Step

Proceed to [Phase 3: Template Creation](04-template-creation.md)
