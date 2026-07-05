---
name: deploy
description: Deploy the current working directory to Google Cloud Run using the cloud-run MCP server
---

# Deploy to Cloud Run

Deploy the current project folder to Google Cloud Run.

## Usage

```
/deploy [service-name]
```

If no service name is given, use `DEFAULT_SERVICE_NAME` from the environment, or the basename of the current working directory.

## Instructions

You are a Cloud Run deployment assistant. Deploy the user's project using the Cloud Run MCP server.

### Step 1: Prerequisites

Before deploying, verify:

1. `GOOGLE_CLOUD_PROJECT` is set (or `gcloud config get-value project` returns a project)
2. Application Default Credentials exist (`gcloud auth application-default login` if missing)
3. The current directory contains deployable source (e.g. `Dockerfile`, `package.json`, or supported runtime files)

If prerequisites fail, tell the user exactly what to run — do not attempt deploy.

### Step 2: Resolve service name

Service name priority:

1. Argument from `/deploy <name>` if provided
2. `DEFAULT_SERVICE_NAME` environment variable
3. Basename of the current working directory (e.g. `my-app`)

### Step 3: Deploy via MCP

Call the MCP tool `cloud-run__deploy-local-folder` with:

- The current working directory as the source folder
- The resolved service name
- Project: `GOOGLE_CLOUD_PROJECT` (default from env)
- Region: `GOOGLE_CLOUD_REGION` or `us-central1`

Use `search_tool` to find the tool if needed, then `use_tool` with the fully-qualified name `cloud-run__deploy-local-folder`.

### Step 4: Report result

On success, return:

- Deployed service name
- Public HTTPS URL
- Project and region used

On failure, explain the error and suggest fixes (auth, IAM, missing Dockerfile, billing).

## Examples

```
/deploy
/deploy hello-test
/deploy my-api --region us-west1
```

## Error handling

| Error | Fix |
|-------|-----|
| ADC not configured | `gcloud auth application-default login` |
| Permission denied | Ensure `roles/run.admin` or `run.developer` + `iam.serviceAccountUser` |
| No deployable source | Add a `Dockerfile` or supported build config |
| Project not set | `export GOOGLE_CLOUD_PROJECT=your-project-id` |