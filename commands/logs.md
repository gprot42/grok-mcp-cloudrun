---
name: logs
description: Get logs and errors for a Google Cloud Run service using the cloud-run MCP server
---

# Cloud Run Logs

Fetch recent logs and error messages for a Cloud Run service.

## Usage

```
/logs [service-name]
```

If no service name is given, use `DEFAULT_SERVICE_NAME` from the environment, or the basename of the current working directory.

## Instructions

You are a Cloud Run logs assistant. Fetch logs for the requested service using the Cloud Run MCP server.

### Step 1: Prerequisites

Before fetching logs, verify:

1. `GOOGLE_CLOUD_PROJECT` is set (or `gcloud config get-value project` returns a project)
2. Application Default Credentials exist (`gcloud auth application-default login` if missing)

### Step 2: Resolve service name

Service name priority:

1. Argument from `/logs <name>` if provided
2. `DEFAULT_SERVICE_NAME` environment variable
3. Basename of the current working directory

### Step 3: Fetch logs via MCP

Call `cloud-run__get-service-log` with:

- Service name (resolved above)
- Project: `GOOGLE_CLOUD_PROJECT`
- Region: `GOOGLE_CLOUD_REGION` or `us-central1`

Use `search_tool` to find the tool if needed, then `use_tool` with the fully-qualified name.

### Step 4: Present results

Format log output clearly:

- Highlight errors and warnings
- Show timestamps when available
- If the service does not exist, suggest `cloud-run__list-services` to find available services

## Examples

```
/logs
/logs hello-test
/logs my-api
```

## Error handling

| Error | Fix |
|-------|-----|
| Service not found | Run `cloud-run__list-services` to list services in the project/region |
| ADC not configured | `gcloud auth application-default login` |
| Permission denied | Ensure `roles/logging.viewer` and Cloud Run read access |