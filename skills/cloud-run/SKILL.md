---
name: cloud-run
description: >
  Deploy and manage Google Cloud Run services and jobs. Use when the user asks
  to deploy to Cloud Run, get Cloud Run logs, list Cloud Run services, manage
  Cloud Run jobs, or invokes /deploy or /logs. Requires gcloud CLI and the
  cloud-run MCP server.
metadata:
  version: 0.2.0
  short-description: 'Deploy and manage Cloud Run via MCP'
---

# Cloud Run for Grok

> **PREREQUISITES:**
>
> - `gcloud` CLI installed and authenticated: `gcloud auth login`
> - Application Default Credentials: `gcloud auth application-default login`
> - Project set: `export GOOGLE_CLOUD_PROJECT=your-project-id` (or
>   `gcloud config set project`)
> - Region (optional): `export GOOGLE_CLOUD_REGION=us-central1`
> - Cloud Run MCP server enabled (`/mcps` shows `cloud-run`)

## MCP-first workflow

Prefer Cloud Run MCP tools (namespaced as `cloud-run__<tool>` in Grok):

| Task                  | MCP tool                         | Slash command |
| --------------------- | -------------------------------- | ------------- |
| Deploy current folder | `cloud-run__deploy-local-folder` | `/deploy`     |
| List services         | `cloud-run__list-services`       | —             |
| Service details + URL | `cloud-run__get-service`         | —             |
| Service logs          | `cloud-run__get-service-log`     | `/logs`       |
| List GCP projects     | `cloud-run__list-projects`       | —             |

**Default service name:** `DEFAULT_SERVICE_NAME` env var, or current directory
basename.

**Deploy steps:**

1. Verify prerequisites (auth, project, deployable source in cwd)
2. Call `cloud-run__deploy-local-folder` with cwd, service name, project, region
3. Return the public HTTPS URL on success

**Logs steps:**

1. Resolve service name (arg → `DEFAULT_SERVICE_NAME` → cwd basename)
2. Call `cloud-run__get-service-log`
3. Highlight errors and recent log lines

## Safety notes

- `SKIP_IAM_CHECK` defaults to `true` upstream — new services may be publicly
  accessible. Set `SKIP_IAM_CHECK=false` to enforce IAM checks before making a
  service public.
- `cloud-run__create-project` creates billable resources. The plugin blocks this
  unless `CONFIRM_CLOUD_RUN_CREATE_PROJECT=1` is set.
- Deploy tools to production-like projects (`*prod*`, `*production*` in project
  ID) are blocked unless `CONFIRM_CLOUD_RUN_PROD_DEPLOY=1` is set.

## gcloud fallback

When MCP is unavailable, use `gcloud run` directly:

```bash
gcloud run <resource> <method> [flags]
```

### services

- `list` — List services in a region
- `describe` — Service details and URL
- `update` — Update env vars, concurrency, etc.
- `delete` — Delete a service
- `logs read` — Read service logs
- `deploy` — Create or update a service (helper)

### jobs

- `list`, `describe`, `deploy`, `execute`, `delete`, `logs read`

### revisions

- `list`, `describe`, `delete`

### regions

- `list` — Available Cloud Run regions

Discover flags with `gcloud run --help` and `gcloud run deploy --help`.

## IAM requirements

Minimum roles for deploy/list/logs:

- `roles/run.admin` (or `roles/run.developer` + `roles/iam.serviceAccountUser`)
- Storage / Artifact Registry access for source uploads (often
  `roles/storage.admin`, `roles/artifactregistry.writer`)

## Common errors

| Symptom                | Fix                                                                           |
| ---------------------- | ----------------------------------------------------------------------------- |
| MCP connection timeout | Increase `startup_timeout_sec` to 60 in config; cold `npx` downloads are slow |
| ADC not found          | `gcloud auth application-default login`                                       |
| Permission denied      | Check IAM roles above                                                         |
| Wrong project          | `export GOOGLE_CLOUD_PROJECT=...` or `gcloud config set project`              |
