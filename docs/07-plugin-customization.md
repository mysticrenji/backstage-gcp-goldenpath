# Backstage Plugin Customization

This guide covers adding the following plugins to the Backstage Docker image:

- **AWS ECS** - View Amazon Elastic Container Service tasks and services on entity pages
- **AWS Cost Insights** - Display AWS cost information per team/component
- **GitLab** - Show merge requests, pipelines, languages, and contributors from GitLab

> **Important:** Backstage plugins must be compiled into the application at build time. There is no runtime plugin installation. Every plugin change requires a Docker image rebuild.

---

## Prerequisites

- Working Backstage application (see [02-backstage-setup.md](02-backstage-setup.md))
- AWS account with appropriate IAM permissions (for AWS plugins)
- GitLab instance with API access token (for GitLab plugin)
- Node.js 22+ and Yarn 4.x

---

## 1. Install Packages

From the `genai-platform/` directory, install the frontend and backend packages:

```bash
# Frontend packages
yarn --cwd packages/app add \
  @aws/amazon-ecs-plugin-for-backstage \
  @backstage-community/plugin-cost-insights \
  @aws/cost-insights-plugin-for-backstage \
  @immobiliarelabs/backstage-plugin-gitlab

# Backend packages
yarn --cwd packages/backend add \
  @aws/amazon-ecs-plugin-for-backstage-backend \
  @aws/cost-insights-plugin-for-backstage-backend \
  @immobiliarelabs/backstage-plugin-gitlab-backend
```

---

## 2. Backend Configuration

Edit `packages/backend/src/index.ts` and add the following lines before `backend.start()`:

```typescript
// Amazon ECS
backend.add(import('@aws/amazon-ecs-plugin-for-backstage-backend'));

// AWS Cost Insights
backend.add(import('@aws/cost-insights-plugin-for-backstage-backend'));

// GitLab
backend.add(import('@immobiliarelabs/backstage-plugin-gitlab-backend'));
```

Full file after changes:

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

// Permission
backend.add(import('@backstage/plugin-permission-backend'));
backend.add(import('@backstage/plugin-permission-backend-module-allow-all-policy'));

// Amazon ECS
backend.add(import('@aws/amazon-ecs-plugin-for-backstage-backend'));

// AWS Cost Insights
backend.add(import('@aws/cost-insights-plugin-for-backstage-backend'));

// GitLab
backend.add(import('@immobiliarelabs/backstage-plugin-gitlab-backend'));

backend.start();
```

---

## 3. Frontend Configuration

### 3.1 Cost Insights Route — `packages/app/src/App.tsx`

Add imports at the top of the file:

```typescript
import { costInsightsAwsPlugin } from '@aws/cost-insights-plugin-for-backstage';
import { CostInsightsPage } from '@backstage-community/plugin-cost-insights';
```

Register the plugin in `createApp`:

```typescript
const app = createApp({
  apis,
  plugins: [costInsightsAwsPlugin],
  bindRoutes({ bind }) {
    // ... existing bindings
  },
  components: {
    SignInPage: props => <SignInPage {...props} auto providers={['guest']} />,
  },
});
```

Add the route inside `<FlatRoutes>`:

```tsx
<Route path="/cost-insights" element={<CostInsightsPage />} />
```

### 3.2 ECS and GitLab Entity Tabs — `packages/app/src/components/catalog/EntityPage.tsx`

Add imports at the top of the file:

```typescript
import { EntityAmazonEcsServicesContent } from '@aws/amazon-ecs-plugin-for-backstage';
import {
  isGitlabAvailable,
  EntityGitlabContent,
} from '@immobiliarelabs/backstage-plugin-gitlab';
```

Add tabs to `serviceEntityPage` (inside the `<EntityLayout>` block, after the existing routes):

```tsx
const serviceEntityPage = (
  <EntityLayout>
    {/* ... existing routes (Overview, CI/CD, Kubernetes, API, Dependencies, Docs) ... */}

    <EntityLayout.Route path="/ecs" title="Amazon ECS">
      <EntityAmazonEcsServicesContent />
    </EntityLayout.Route>

    <EntityLayout.Route if={isGitlabAvailable} path="/gitlab" title="GitLab">
      <EntityGitlabContent />
    </EntityLayout.Route>
  </EntityLayout>
);
```

Optionally add the same routes to `websiteEntityPage` and `defaultEntityPage` if needed.

### 3.3 (Optional) Cost Insights Sidebar Link — `packages/app/src/components/Root/Root.tsx`

Add a sidebar entry for Cost Insights:

```typescript
import MoneyIcon from '@material-ui/icons/MonetizationOn';

// Inside the <Sidebar> component:
<SidebarItem icon={MoneyIcon} to="cost-insights" text="Cost Insights" />
```

---

## 4. App Config Updates

### 4.1 `app-config.yaml`

Add the following sections:

```yaml
# Cost Insights
costInsights:
  engineerCost: 200000

# GitLab plugin settings
gitlab:
  allowedKinds: ['Component']
```

The GitLab integration is already configured under `integrations.gitlab`. Ensure the token has API read access:

```yaml
integrations:
  gitlab:
    - host: gitlab.com
      token: ${GITLAB_TOKEN}
      apiBaseUrl: https://gitlab.com/api/v4
```

### 4.2 `app-config.production.yaml`

Add the same `costInsights` and `gitlab` sections to the production config if they differ from development.

---

## 5. Entity Annotations

For the plugins to display data on entity pages, annotate your `catalog-info.yaml` files.

### Amazon ECS

Use tag-based lookup (matches ECS services by AWS resource tags):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    aws.amazon.com/amazon-ecs-service-tags: component=my-service,environment=prod
```

Or reference a specific service ARN directly:

```yaml
  annotations:
    aws.amazon.com/amazon-ecs-service-arn: arn:aws:ecs:us-west-2:123456789:service/my-cluster/my-service
```

### AWS Cost Insights

```yaml
  annotations:
    aws.amazon.com/cost-insights-tags: component=my-service,environment=prod
```

### GitLab

Use the project slug:

```yaml
  annotations:
    gitlab.com/project-slug: 'my-group/my-project'
```

Or the numeric project ID:

```yaml
  annotations:
    gitlab.com/project-id: '12345'
```

---

## 6. AWS IAM Permissions

The AWS plugins use the [default AWS SDK credential chain](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/setting-credentials-node.html). Create an IAM policy with the following permissions and attach it to the identity running Backstage:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECSPlugin",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:DescribeClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CostInsightsPlugin",
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AWSCommon",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

> Restrict `Resource` to specific ARNs for production use.

### Authentication on Kubernetes

| Platform | Method |
|----------|--------|
| **EKS** | Use [IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html). Annotate the Backstage ServiceAccount with the IAM role ARN. |
| **GKE / other** | Set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_DEFAULT_REGION` as environment variables in the pod spec or Helm values. |

---

## 7. Build the Docker Image

The existing `Dockerfile` at `packages/backend/Dockerfile` handles everything. No changes to the Dockerfile are needed.

```bash
cd genai-platform

# Install dependencies
yarn install --immutable

# Type-check
yarn tsc

# Build the backend (bundles frontend + backend)
yarn build:backend

# Build the Docker image
yarn build-image
```

This produces an image tagged `backstage` locally. To push to a registry:

```bash
docker tag backstage <registry>/backstage:<version>
docker push <registry>/backstage:<version>
```

Then update your Kubernetes deployment or Helm values to reference the new image tag.

---

## 8. Verification

After deploying the new image:

1. **ECS plugin** - Navigate to a catalog entity with ECS annotations. An "Amazon ECS" tab should appear showing service/task details.
2. **Cost Insights** - Navigate to `/cost-insights` in the sidebar. Cost data grouped by AWS tags should render.
3. **GitLab plugin** - Navigate to a catalog entity with GitLab annotations. A "GitLab" tab should appear showing merge requests, pipelines, and contributors.

Check backend health endpoints:

```
GET /api/amazon-ecs/health    -> {"status":"ok"}
```

---

## Plugin Reference

| Plugin | Frontend Package | Backend Package | Docs |
|--------|-----------------|-----------------|------|
| Amazon ECS | `@aws/amazon-ecs-plugin-for-backstage` | `@aws/amazon-ecs-plugin-for-backstage-backend` | [GitHub](https://github.com/awslabs/backstage-plugins-for-aws/tree/main/plugins/ecs) |
| Cost Insights | `@backstage-community/plugin-cost-insights` + `@aws/cost-insights-plugin-for-backstage` | `@aws/cost-insights-plugin-for-backstage-backend` | [GitHub](https://github.com/awslabs/backstage-plugins-for-aws/tree/main/plugins/cost-insights) |
| GitLab | `@immobiliarelabs/backstage-plugin-gitlab` | `@immobiliarelabs/backstage-plugin-gitlab-backend` | [GitHub](https://github.com/immobiliare/backstage-plugin-gitlab) |
