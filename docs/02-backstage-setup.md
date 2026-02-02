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

## Next Step

Proceed to [Phase 2: Blueprint Creation](03-blueprint-creation.md)
