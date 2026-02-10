# How I Built a Self-Service AI Platform So Data Scientists Would Stop Bugging Me

*A hands-on guide to building a "Golden Path" with Backstage, GitLab, and Google Cloud — from zero to one-click GenAI environments.*

---

If you've ever worked as a platform engineer, you know the drill. A data scientist walks up to your desk (or, more likely, pings you on Slack at 11 PM) and says something like: "Hey, I need a storage bucket, Vertex AI access, a service account, and proper IAM bindings for my new experiment. Can you set that up by tomorrow?"

You say sure, open the GCP console, click around for twenty minutes, realize you forgot to enable the right API, go back, fix it, bind the wrong IAM role, debug that for another hour, and eventually get it done. The data scientist is happy. You're exhausted. And next week, another one shows up with the exact same request.

I got tired of this cycle. So I built a system where data scientists can provision their own secure, compliant GenAI environments with a single click — no Slack messages, no GCP console clicking, no 11 PM pings. This article walks you through exactly how I did it, step by step.

---

## What We're Actually Building

Before I dump a bunch of YAML on you, let me explain the big picture. The whole system has three layers, and once you understand them, everything else makes sense.

**Layer 1: The Interface (Backstage)**
This is the web portal where your data scientists go to request stuff. They fill out a form — "What's your project name? Which GCP project? What region?" — and hit submit. That's it. That's all they ever have to do.

**Layer 2: The Source of Truth (GitLab)**
When they hit submit, Backstage doesn't go create cloud resources directly. Instead, it generates a bunch of YAML files and pushes them to a new GitLab repository. These YAML files describe *what* resources should exist. Think of it as a shopping list for cloud infrastructure.

**Layer 3: The Engine (GKE + Config Connector)**
This is where the magic happens. A Kubernetes cluster running Google's Config Connector watches those GitLab repos. When it sees new YAML files, it reads them and makes the corresponding API calls to GCP. Storage bucket? Created. Vertex AI? Enabled. IAM bindings? Done.

The flow looks like this:

```
Data Scientist fills form → Backstage generates YAML → GitLab stores it →
Config Connector reads it → GCP resources get created
```

No human in the loop after that initial form. No tickets. No waiting. The whole thing takes about five minutes from button click to ready-to-use infrastructure.

---

## Why I Call It a "Golden Path"

The term "Golden Path" comes from Spotify's engineering culture. The idea is simple: instead of giving developers a blank canvas and saying "figure it out," you give them a pre-paved road that leads to the right destination.

It's opinionated on purpose. Every GenAI environment created through this path gets the same security controls, the same labeling conventions, the same IAM structure. There's no room for someone to accidentally make a storage bucket publicly accessible or forget to enable versioning. The guardrails are baked in.

But it's not restrictive — data scientists still pick their project name, region, and environment. They get autonomy where it matters, and safety where it counts.

---

## The Real Problem: Developer Experience Is Broken

Before we get into the technical setup, I want to talk about *why* this matters — not from a platform engineering angle, but from the perspective of the people we're building for. Because honestly, the infrastructure is the easy part. The hard part is understanding what makes developers (and data scientists) productive in the first place.

### Cognitive Load Is the Silent Killer

There's a concept in psychology called cognitive load — the amount of mental effort your working memory is handling at any given moment. It's the reason you can't solve a tricky coding problem while someone's reading you a grocery list.

Here's the thing about infrastructure provisioning: it's pure cognitive overhead. When a data scientist has to learn Terraform syntax, understand IAM role hierarchies, figure out which GCP APIs need enabling, and debug Kubernetes manifests — that's all *extraneous* cognitive load. None of it has anything to do with the actual problem they're trying to solve, which is building an AI model.

Team Topologies by Matthew Skelton and Manuel Pais talks about three types of cognitive load:

- **Intrinsic** — the complexity inherent to the problem domain (designing ML models, tuning hyperparameters)
- **Extraneous** — the complexity imposed by the environment (provisioning infrastructure, navigating cloud consoles)
- **Germane** — the effort of learning new things that actually help you get better at your job

Traditional infrastructure workflows dump enormous extraneous cognitive load onto people who should be spending their brainpower on intrinsic and germane work. A data scientist debugging a Terraform state file isn't learning anything that makes them a better data scientist. They're just trying to get past a roadblock that shouldn't exist.

The Golden Path eliminates that extraneous load almost entirely. Fill out a form. Click a button. Done. Now go think about your actual problem.

### Feedback Loops: The Tighter, The Better

Here's a question: how long does it take from the moment a data scientist has an idea for an experiment to the moment they have infrastructure ready to run it?

In most organizations I've seen, the answer is somewhere between two days and two weeks. That's two days of: filing a ticket, waiting for a platform engineer to pick it up, back-and-forth on requirements, manual provisioning, testing, handing over credentials, and finally getting access.

That delay is a feedback loop — and it's absurdly long.

Think about how tight the feedback loop is when you're writing code in an IDE. You type something, you run it, you see the result in seconds. That speed is what keeps you engaged. It's what lets you iterate. It's what makes you productive.

Now compare that to infrastructure. You have an idea on Monday. You get your environment on Thursday. By Thursday, your mental model of what you were trying to build has gone stale. You've context-switched to three other things. You have to reload the entire problem space back into your head before you can even start working.

The Golden Path compresses that feedback loop from days to minutes. Idea → form → submit → infrastructure ready. The mental model stays fresh. The momentum stays alive. And the experiment that might have died in a ticket queue actually gets built.

### Value Stream: Where Does the Time Actually Go?

If you've ever done a value stream mapping exercise, you know the drill. You trace the journey from "customer request" to "value delivered" and measure how much of that time is actual *work* versus *waiting*.

For infrastructure provisioning, the results are almost always embarrassing. The actual work — someone clicking buttons in a console or writing Terraform — might take 30 minutes. But the end-to-end lead time is days, sometimes weeks. The rest is all waiting. Waiting in a ticket queue. Waiting for approvals. Waiting for someone to be available. Waiting for access.

Lean manufacturing figured this out decades ago: inventory (work sitting in queues) is waste. Every handoff between teams introduces delay. Every manual approval step is a bottleneck.

The Golden Path collapses the value stream by removing the handoffs entirely. There is no ticket. There is no queue. There is no approval step for standard infrastructure (because the Golden Path *is* the approved path — it was reviewed and approved when we built it). The work goes from "requested" to "done" without stopping at anyone's desk.

This doesn't just help individual data scientists. It changes the math for the entire organization. If you have fifty data scientists each losing three days per quarter waiting for infrastructure, that's 150 person-days of lost productivity. Per quarter. That's almost an entire full-time engineer's output — just gone, absorbed by waiting.

### Flow State and the Cost of Interruption

There's a well-known study (Gloria Mark, UC Irvine) that found it takes about 23 minutes to get back into a focused state after an interruption. Twenty-three minutes. Just to get back to where you were.

Now think about what happens during the traditional provisioning flow. The data scientist files a request. Switches to something else. Gets pinged back: "What region did you want?" Switches context. Answers the question. Switches back. Gets pinged again: "Do you need Vertex AI or just Cloud AI Platform?" Switches context. Answers. Gets pinged again two days later: "It's ready, here's the service account key." Tries to remember what they were building.

Every one of those interruptions costs 23 minutes of focus recovery. More importantly, each one pulls the person out of what psychologist Mihaly Csikszentmihalyi calls *flow state* — that deeply focused, highly productive state where the work feels effortless and time disappears.

Flow state is where the best work happens. It's where insights emerge. It's where a data scientist goes from "this model kind of works" to "this model is actually good." And it's incredibly fragile. One Slack notification about a missing IAM role can shatter it.

The Golden Path protects flow state by making infrastructure provisioning a single, uninterrupted action. There's no back-and-forth. No waiting for responses. No context switching. You fill out the form, you get your infrastructure, and you get back to the work that matters — all within the same sitting.

### Putting It All Together

These four concepts — cognitive load, feedback loops, value streams, and flow state — aren't just academic theory. They're the reason platforms succeed or fail. A platform can have the most elegant architecture in the world, but if it dumps cognitive load on users, introduces multi-day feedback loops, creates value stream bottlenecks, and destroys flow state — nobody will use it.

The Golden Path is designed around these principles:

| Principle | Traditional Approach | Golden Path |
|-----------|---------------------|-------------|
| **Cognitive Load** | Learn Terraform, IAM, GCP console, Kubernetes | Fill out a form |
| **Feedback Loop** | Days to weeks | 5 minutes |
| **Value Stream** | Multiple handoffs, ticket queues, approvals | Single self-service action |
| **Flow State** | Constant interruptions across days | One uninterrupted interaction |

This is why I built it. Not because GitOps is cool (though it is). Not because Config Connector is neat (though it is). But because the people I'm building for — the data scientists, the ML engineers, the researchers — deserve to spend their time on *their* work, not on mine.

---

## What You'll Need Before Starting

Let me be upfront: this isn't a "follow along in 10 minutes" tutorial. You'll need some real infrastructure. Here's the shopping list:

**On your local machine:**
- Node.js (v20 or later)
- Yarn package manager
- Docker
- `gcloud` CLI (authenticated)
- `kubectl`

**In the cloud:**
- A GCP project with billing enabled
- A GitLab account with a Personal Access Token (you'll need `api`, `read_user`, and `write_repository` scopes)

**What you should be comfortable with:**
- Basic Kubernetes concepts (pods, namespaces, manifests)
- Using the terminal
- YAML (you're going to see a lot of it)

If you've never touched Kubernetes before, I'd recommend going through a basic GKE tutorial first. This guide assumes you know what `kubectl apply` does.

---

## Phase 0: Setting Up the Foundation

### Creating the GKE Cluster

We're using GKE Autopilot, not Standard GKE. There's a good reason for this: Autopilot charges you per pod, not per node. For a platform like this where workloads are bursty — someone provisions infrastructure, Config Connector does its thing, then everything goes quiet — you don't want to pay for idle nodes sitting around.

Autopilot also handles node management, security patching, and comes with Workload Identity enabled by default. That last part matters a lot because it means we never have to deal with service account key files.

```bash
# Set your project ID
export GCP_PROJECT_ID="your-project-id-here"
gcloud config set project $GCP_PROJECT_ID

# Enable the APIs we need
gcloud services enable container.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com

# Create the cluster (this takes a few minutes)
gcloud container clusters create-auto golden-path-cluster \
  --region europe-west1 \
  --project=${GCP_PROJECT_ID}

# Get credentials so kubectl can talk to it
gcloud container clusters get-credentials golden-path-cluster \
  --region europe-west1 \
  --project=${GCP_PROJECT_ID}
```

Quick sanity check — make sure you're connected:

```bash
kubectl cluster-info
kubectl get nodes
```

If you see node information, you're good. If you get an authentication error, run the `get-credentials` command again.

### Setting Up Config Connector

Config Connector is the bridge between Kubernetes YAML and actual GCP resources. You write a YAML file that says "I want a storage bucket," apply it to your cluster, and Config Connector calls the GCP API to create it.

First, we need a GCP service account that Config Connector will use to make those API calls:

```bash
# Create the service account
gcloud iam service-accounts create config-connector-sa \
  --display-name="Config Connector Service Account"

# Give it permission to create storage buckets
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/storage.admin"

# Give it permission to manage Vertex AI
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/aiplatform.admin"

# Give it permission to enable/disable APIs
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageAdmin"
```

Now, here's the part that trips people up. We need to connect the Kubernetes service account (the identity Config Connector runs as *inside* the cluster) to the GCP service account (the identity that has permission to create cloud resources). This is called Workload Identity:

```bash
gcloud iam service-accounts add-iam-policy-binding \
  config-connector-sa@${GCP_PROJECT_ID}.iam.gserviceaccount.com \
  --member="serviceAccount:${GCP_PROJECT_ID}.svc.id.goog[cnrm-system/cnrm-controller-manager]" \
  --role="roles/iam.workloadIdentityUser"
```

What that command does in plain English: it tells GCP "when the `cnrm-controller-manager` service account in the `cnrm-system` namespace on my cluster says it's `config-connector-sa`, trust it."

No keys. No JSON files. No secrets to rotate. The authentication happens automatically through Google's identity federation. It's honestly one of the more elegant pieces of this whole setup.

Now configure Config Connector itself:

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

Wait for it to be ready:

```bash
kubectl wait -n cnrm-system \
  --for=condition=Ready pod \
  -l cnrm.cloud.google.com/component=cnrm-controller-manager \
  --timeout=300s
```

If this completes without timing out, Config Connector is up and running.

---

## Phase 1: Setting Up Backstage

Backstage is an open-source developer portal originally created at Spotify. It's the front door of our platform — the thing users actually interact with.

### Scaffolding the App

```bash
npx @backstage/create-app@latest
```

When it asks for a name, type `genai-platform`. For the database, pick SQLite — it's fine for development, and we'll switch to PostgreSQL when we deploy to Kubernetes.

```bash
cd genai-platform
```

### Connecting Backstage to GitLab

Backstage needs a GitLab token so it can create repositories on behalf of your users. Set it as an environment variable:

```bash
export GITLAB_TOKEN='glpat-YOUR_TOKEN_HERE'
```

Then open `app-config.yaml` and add the GitLab integration:

```yaml
integrations:
  gitlab:
    - host: gitlab.com
      token: ${GITLAB_TOKEN}
      apiBaseUrl: https://gitlab.com/api/v4
```

Notice the `${GITLAB_TOKEN}` — Backstage substitutes environment variables at runtime. Your actual token never appears in config files that get committed to Git.

### Installing the GitLab Scaffolder Plugin

The default Backstage installation doesn't know how to publish to GitLab. We need to add that capability:

```bash
yarn --cwd packages/backend add @backstage/plugin-scaffolder-backend-module-gitlab
```

Then register it in `packages/backend/src/index.ts`:

```typescript
backend.add(import('@backstage/plugin-scaffolder-backend-module-gitlab'));
```

Fire it up to make sure everything works:

```bash
yarn start
```

Open `http://localhost:3000`. If you see the Backstage homepage, you're in business.

---

## Phase 2: Creating the Blueprint

This is where it gets interesting. We're going to create the files that Backstage generates when someone uses our Golden Path. These are template files with placeholders that get replaced with user input.

Create the directory structure:

```bash
mkdir -p packages/backend/templates/genai-gitlab-blueprint/{infra,src}
```

### The Infrastructure Files

**`infra/storage.yaml` — The Data Lake**

```yaml
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

See those `${{ values.component_id }}` placeholders? When a data scientist names their project "fraud-detection-v2," that placeholder becomes `fraud-detection-v2-data`. The bucket gets uniform access (so you can't accidentally make individual objects public), versioning (so you can recover deleted data), and a lifecycle rule that auto-deletes objects after a year.

This is what I mean by "guardrails baked in." Every bucket created through the Golden Path follows these security practices. Nobody has to remember to check the versioning box.

**`infra/vertex.yaml` — Enabling Vertex AI**

```yaml
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

This one's short but important. It enables the Vertex AI API in the specified GCP project. The `abandon` deletion policy means that if someone deletes this Kubernetes resource, the API stays enabled — you don't want a cleanup operation to accidentally break other services that depend on it.

**`infra/iam.yaml` — Service Account and Permissions**

```yaml
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

This creates a dedicated service account for each GenAI project and grants it exactly two roles: `storage.objectUser` (read/write the data bucket) and `aiplatform.user` (use Vertex AI). Nothing more. Principle of least privilege, enforced by code.

### The Application Skeleton

**`src/app.py` — A Streamlit Chatbot**

```python
import streamlit as st
import vertexai
from vertexai.generative_models import GenerativeModel, ChatSession

PROJECT_ID = "${{ values.gcp_project_id }}"
REGION = "${{ values.gcp_region }}"
MODEL_ID = "gemini-2.5-flash"

st.set_page_config(
    page_title="${{ values.component_id }}",
    page_icon="🤖",
    layout="wide"
)

st.title("🤖 ${{ values.component_id }}")
st.caption("Deployed via the AI Golden Path")

@st.cache_resource
def init_vertex_ai():
    vertexai.init(project=PROJECT_ID, location=REGION)
    return GenerativeModel(MODEL_ID)

def main():
    try:
        model = init_vertex_ai()
        chat = model.start_chat()
        st.success("✅ Connected to Vertex AI")
    except Exception as e:
        st.error(f"Failed to initialize Vertex AI: {e}")
        return

    if "messages" not in st.session_state:
        st.session_state.messages = []

    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    if prompt := st.chat_input("Ask me anything..."):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

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

Every Golden Path project ships with a working chatbot out of the box. Data scientists can modify it, swap models, add RAG pipelines — but they start with something that works, not an empty folder and a README that says "good luck."

### The Catalog File

**`catalog-info.yaml`**

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.component_id }}
  description: ${{ values.description }}
  annotations:
    gitlab.com/project-slug: ${{ values.repoOwner }}/${{ values.component_id }}
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
```

This file registers the service back into Backstage's catalog, so it shows up in the service directory. Other teams can discover it, see who owns it, and find links to the GCP console.

---

## Phase 3: The Template (The Form Definition)

Now we need to define what the form looks like. This is a YAML file that tells Backstage "show these fields, then do these things when the user clicks submit."

**`template.yaml`**

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
          description: Unique identifier for your service
          pattern: '^[a-z0-9-]+$'
          ui:field: EntityNamePicker
        description:
          title: Description
          type: string
          default: A new GenAI experiment
        owner:
          title: Owner
          type: string
          ui:field: OwnerPicker

    - title: Infrastructure Configuration
      required:
        - gcp_project_id
        - gcp_region
      properties:
        gcp_project_id:
          title: Google Cloud Project ID
          type: string
        gcp_region:
          title: GCP Region
          type: string
          default: us-central1
          enum:
            - us-central1
            - europe-west1
            - asia-northeast1
        environment:
          title: Environment
          type: string
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
        repoVisibility:
          title: Repository Visibility
          type: string
          default: private
          enum:
            - private
            - internal
            - public

  steps:
    - id: fetch-base
      name: 📂 Fetching Blueprint
      action: fetch:template
      input:
        url: ./
        values:
          component_id: ${{ parameters.component_id }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          gcp_project_id: ${{ parameters.gcp_project_id }}
          gcp_region: ${{ parameters.gcp_region }}
          environment: ${{ parameters.environment }}
          repoOwner: ${{ parameters.repoOwner }}

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

    - id: register
      name: 📝 Registering in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps['publish'].output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml

  output:
    links:
      - title: 🦊 Source Code Repository
        url: ${{ steps['publish'].output.remoteUrl }}
      - title: 🟧 Open in Catalog
        icon: catalog
        entityRef: ${{ steps['register'].output.entityRef }}
      - title: ☁️ GCP Console
        url: https://console.cloud.google.com/home/dashboard?project=${{ parameters.gcp_project_id }}
```

The template has three sections that matter:

1. **Parameters** — the form fields. Backstage renders these as a multi-step wizard.
2. **Steps** — the automation. First it fills in the templates, then publishes to GitLab, then registers in the catalog.
3. **Output** — the links shown after everything completes. Users get direct links to their new repo, the Backstage catalog entry, and the GCP console.

---

## Phase 4: Registering the Template and Going Live

Open `app-config.yaml` and tell Backstage where to find your template:

```yaml
catalog:
  rules:
    - allow: [Component, System, API, Resource, Location, Template]
  locations:
    - type: file
      target: ./packages/backend/templates/genai-gitlab-blueprint/template.yaml
      rules:
        - allow: [Template]
```

Start Backstage:

```bash
yarn start
```

Go to `http://localhost:3000`, click **Create** in the sidebar, and you should see your "GenAI RAG Application (GitLab)" template. Fill in the form, click create, and watch Backstage do its thing.

When it's done, check your GitLab — there's a brand new repository with all the infrastructure files, the application code, and the catalog entry. All the placeholders have been replaced with the values you entered.

---

## Phase 5: Closing the Loop with GitOps

At this point, we have a repo full of YAML in GitLab and a Kubernetes cluster running Config Connector. We need something to bridge the gap — something that watches GitLab for new repos and applies those YAML files to the cluster.

You have two solid options here.

### Option A: ArgoCD

ArgoCD is a GitOps controller that lives in your cluster and syncs Git repositories to Kubernetes. It has a nice UI for visualizing deployment status.

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

The real power comes from ApplicationSets. Instead of manually creating an ArgoCD application for every Golden Path project, you can set up an ApplicationSet that automatically discovers new GitLab repos that contain `infra/storage.yaml`:

```yaml
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

Now when a data scientist creates a new project through Backstage, ArgoCD automatically picks it up, applies the infrastructure YAML to the cluster, and Config Connector creates the GCP resources. Zero manual intervention.

### Option B: GitLab Agent for Kubernetes

If you're already invested in GitLab's ecosystem, the GitLab Agent is a lighter-weight alternative. It's a pull-based agent that connects your cluster to GitLab without exposing your cluster API to the internet.

The setup involves installing a Helm chart and configuring which GitLab projects/groups the agent should watch. It works well, but ArgoCD gives you better visibility into sync status and drift detection.

---

## The End-to-End Flow

Let me walk through what actually happens when a data scientist uses this system:

1. They open Backstage, find the "GenAI RAG Application" template, and fill in the form. Takes about 30 seconds.

2. Backstage takes their inputs, replaces all the `${{ values.* }}` placeholders in the blueprint files, and pushes everything to a new GitLab repository. Takes about 10 seconds.

3. ArgoCD detects the new repository (either via webhook or its next polling cycle). It applies the files in the `infra/` directory to the Kubernetes cluster.

4. Config Connector sees the new Kubernetes resources — a `StorageBucket`, a `Service`, `IAMServiceAccount`, `IAMPolicyMember` — and starts making GCP API calls.

5. Within a few minutes, the GCS bucket exists, Vertex AI is enabled, the service account has its permissions, and everything is registered in the Backstage catalog.

The data scientist never opened the GCP console. Never wrote a single line of Terraform. Never submitted a ticket. They filled out a form and got a fully provisioned, properly secured AI environment.

---

## What I'd Do Differently Next Time

This setup has been running for a while now, and there are a few things I've learned:

**Add OPA Gatekeeper from day one.** Policy enforcement shouldn't be an afterthought. Gatekeeper can ensure every resource created through Config Connector meets your organization's standards — required labels, approved regions, naming conventions.

**Start with PostgreSQL for Backstage.** I initially used SQLite for simplicity, but the migration to PostgreSQL when moving to Kubernetes was an unnecessary step. Just use PostgreSQL from the start.

**Build monitoring into the template.** The current blueprint creates infrastructure, but it doesn't set up alerts or dashboards. Adding a basic Cloud Monitoring policy for the storage bucket and Vertex AI quotas would make the Golden Path even more complete.

**Consider multi-environment from the beginning.** Right now, the template has an "environment" field but it doesn't create separate namespaces or clusters for dev/staging/prod. If I were starting over, I'd wire that up from the start.

---

## Wrapping Up

The "Golden Path" concept is fundamentally about empathy. As platform engineers, it's easy to fall into the trap of building infrastructure *for* ourselves — complex, flexible, endlessly configurable systems that make perfect sense to someone who thinks in YAML and Terraform all day.

But our users are data scientists. They think in Python, in Jupyter notebooks, in model architectures. They don't want to learn Kubernetes. They shouldn't have to. They just want to get to work.

This platform gives them that. A form, a button, and five minutes later they're writing code against Vertex AI. Everything underneath — the GitOps pipelines, the Config Connector reconciliation loops, the Workload Identity bindings — is invisible to them. And that's exactly how it should be.

The code for the full project is available on GitLab. If you build something similar, I'd love to hear about it.

---

*If you found this helpful, give it a clap. I write about platform engineering, Kubernetes, and making infrastructure disappear. Follow me for more.*

**Tags:** `#PlatformEngineering` `#Kubernetes` `#GCP` `#Backstage` `#GitOps` `#DevOps` `#GenAI` `#InfrastructureAsCode`