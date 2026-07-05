# grok-mcp-cloudrun

**Grok plugin for deploying and managing Google Cloud Run services.**

Deploy and manage Cloud Run from [Grok](https://github.com/xai-org/grok) using
MCP tools, slash commands, and a Cloud Run skill. This repo is a thin wrapper
around Google's open-source
[`@google-cloud/cloud-run-mcp`](https://github.com/GoogleCloudPlatform/cloud-run-mcp)
— it does **not** fork or vendor the upstream server.

**Not affiliated with Google.** See [NOTICE](NOTICE) for upstream attribution.

> See [GROK-CHANGES.md](GROK-CHANGES.md) for a full list of Grok-specific
> additions and lessons learned from testing.

---

## Table of contents

1. [What you get](#what-you-get)
2. [Prerequisites](#prerequisites)
3. [Quick start](#quick-start)
4. [Installation](#installation)
5. [Quick test (deploy + curl)](#quick-test-deploy--curl)
6. [Daily usage](#daily-usage)
7. [Configuration reference](#configuration-reference)
8. [Troubleshooting](#troubleshooting)
9. [Project layout](#project-layout)
10. [Hosted MCP vs local plugin](#hosted-mcp-vs-local-plugin)
11. [License](#license)

---

## What you get

| Component          | What it does                                                       |
| ------------------ | ------------------------------------------------------------------ |
| **MCP server**     | Deploy folders, list services, fetch logs via `cloud-run__*` tools |
| **Skill**          | `cloud-run` — MCP-first workflow with gcloud fallback              |
| **Slash commands** | `/deploy` and `/logs`                                              |
| **Hooks**          | Warns if no GCP project is set; blocks `create-project` by default |

---

## Prerequisites

Install and authenticate before anything else.

### 1. Google Cloud SDK

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Environment variables

```bash
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
export GOOGLE_CLOUD_REGION=us-central1          # optional, defaults to us-central1
export DEFAULT_SERVICE_NAME=                    # optional, defaults to cwd basename
```

### 3. Node.js

Node.js LTS is required for `npx` to spawn the MCP server.

### 4. IAM roles

Your account needs permission to deploy and read Cloud Run resources:

| Action        | Minimum roles                                                                    |
| ------------- | -------------------------------------------------------------------------------- |
| Deploy        | `roles/run.admin` — or `roles/run.developer` + `roles/iam.serviceAccountUser`    |
| Logs          | `roles/logging.viewer` + Cloud Run read access                                   |
| Source upload | `roles/storage.admin`, `roles/artifactregistry.writer` (as needed by your build) |

### 5. Verify MCP connectivity

```bash
grok mcp doctor cloud-run
```

Expected output: `Found 1 healthy, 0 failing` with 8 tools discovered.

---

## Quick start

If this repo is already on your machine:

```bash
# Install and trust the plugin
grok plugin install /path/to/grok-mcp-cloudrun --trust
grok plugin enable cloud-run

# Confirm everything loaded
grok plugin validate /path/to/grok-mcp-cloudrun
grok inspect
```

Open Grok and check:

- `/plugins` — `cloud-run` is enabled
- `/mcps` — `cloud-run` server shows 8 tools
- `/skills` — `cloud-run` skill is listed

---

## Installation

Choose one path. Do **not** enable both with the same server name — pick plugin
**or** bare MCP config.

### Option A: Plugin (recommended)

Includes skills, slash commands, and safety hooks.

```bash
grok plugin install /path/to/grok-mcp-cloudrun --trust
grok plugin enable cloud-run
```

The `--trust` flag is required for MCP servers and hooks to activate.

### Option B: MCP config only

For personal use without the plugin wrapper:

```bash
grok mcp add cloud-run \
  -e GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  -e GOOGLE_CLOUD_REGION=us-central1 \
  -- npx -y @google-cloud/cloud-run-mcp@1.10.0
```

Or add manually to `~/.grok/config.toml`:

```toml
[mcp_servers.cloud-run]
command = "npx"
args = ["-y", "@google-cloud/cloud-run-mcp@1.10.0"]
enabled = true
startup_timeout_sec = 60

[mcp_servers.cloud-run.env]
GOOGLE_CLOUD_PROJECT = "${GOOGLE_CLOUD_PROJECT}"
GOOGLE_CLOUD_REGION  = "${GOOGLE_CLOUD_REGION:-us-central1}"
DEFAULT_SERVICE_NAME = "${DEFAULT_SERVICE_NAME:-}"

[mcp_servers.cloud-run.tool_timeouts]
deploy-local-folder = 600
```

---

## Quick test (deploy + curl)

End-to-end smoke test: clone a sample app, deploy it from Grok, then hit it with
`curl`.

### Step 1 — Clone the sample

```bash
git clone https://github.com/GoogleCloudPlatform/cloud-run-mcp.git /tmp/cloud-run-mcp
cd /tmp/cloud-run-mcp/example-sources-to-deploy/nodejs
```

Upstream also provides `golang`, `java`, and `python` samples in the same
directory.

### Step 2 — Deploy from Grok

In a Grok session (with this directory as your working folder):

```
/deploy hello-test
```

Grok calls `cloud-run__deploy-local-folder` and returns a public HTTPS URL when
the deploy finishes. First deploy can take several minutes (Cloud Build +
container push).

### Step 3 — Verify with curl

Use the URL from the deploy response, or look it up with `gcloud`:

```bash
# Option A: URL from /deploy output
curl -sS https://hello-test-XXXXXXXX-uc.a.run.app/

# Option B: resolve URL via gcloud
SERVICE_URL=$(gcloud run services describe hello-test \
  --region="${GOOGLE_CLOUD_REGION:-us-central1}" \
  --project="${GOOGLE_CLOUD_PROJECT}" \
  --format='value(status.url)')

curl -sS "$SERVICE_URL/"
```

Expected response:

```
Hello from Node.js on Cloud Run!
```

Health check:

```bash
curl -sS -o /dev/null -w "HTTP %{http_code}\n" "$SERVICE_URL/health"
```

Expected: `HTTP 200`

### Step 4 — Check logs

Back in Grok:

```
/logs hello-test
```

Or from the shell:

```bash
gcloud run services logs read hello-test \
  --region="${GOOGLE_CLOUD_REGION:-us-central1}" \
  --limit=20
```

### Step 5 — Clean up (optional)

```bash
gcloud run services delete hello-test \
  --region="${GOOGLE_CLOUD_REGION:-us-central1}" \
  --quiet
```

---

## Daily usage

### Slash commands

| Command          | Action                                        |
| ---------------- | --------------------------------------------- |
| `/deploy`        | Deploy cwd; service name = directory basename |
| `/deploy my-api` | Deploy cwd as `my-api`                        |
| `/logs`          | Logs for default service name                 |
| `/logs my-api`   | Logs for `my-api`                             |

### Natural language prompts

- "List Cloud Run services in `my-project` region `us-central1`"
- "Deploy the current folder to Cloud Run"
- "Get the URL for service `hello-test`"
- "Show me recent errors in Cloud Run logs for `my-api`"

### MCP tools

Grok namespaces tools as `cloud-run__<tool>`:

| Tool                              | Purpose                                  |
| --------------------------------- | ---------------------------------------- |
| `cloud-run__deploy-local-folder`  | Deploy cwd to Cloud Run                  |
| `cloud-run__deploy-file-contents` | Deploy files by content (remote mode)    |
| `cloud-run__list-services`        | List services in project/region          |
| `cloud-run__get-service`          | Service details and public URL           |
| `cloud-run__get-service-log`      | Recent logs and errors                   |
| `cloud-run__list-projects`        | List GCP projects                        |
| `cloud-run__create-project`       | Create project (blocked by default hook) |

Discover tools at runtime with `search_tool`, then call with `use_tool`.

---

## Configuration reference

### Environment variables

| Variable                           | Default           | Description                                                     |
| ---------------------------------- | ----------------- | --------------------------------------------------------------- |
| `GOOGLE_CLOUD_PROJECT`             | —                 | GCP project for all operations                                  |
| `GOOGLE_CLOUD_REGION`              | `us-central1`     | Cloud Run region                                                |
| `DEFAULT_SERVICE_NAME`             | cwd basename      | Default name for `/deploy` and `/logs`                          |
| `SKIP_IAM_CHECK`                   | `true` (upstream) | When `true`, new services may be publicly accessible            |
| `CONFIRM_CLOUD_RUN_CREATE_PROJECT` | unset             | Set to `1` to allow `create-project` (hook blocks it otherwise) |
| `CONFIRM_CLOUD_RUN_PROD_DEPLOY`    | unset             | Set to `1` to deploy when project ID looks like production      |

### Safety hooks

The plugin ships `hooks/hooks.json`:

- **SessionStart** — warns if neither `GOOGLE_CLOUD_PROJECT` nor a `gcloud`
  default project is set; warns if ADC is missing
- **PreToolUse** — blocks `cloud-run__create-project` unless
  `CONFIRM_CLOUD_RUN_CREATE_PROJECT=1`
- **PreToolUse** — blocks deploy tools to production-like projects unless
  `CONFIRM_CLOUD_RUN_PROD_DEPLOY=1`

### Timeouts

Cold `npx` downloads can exceed the default 30s startup timeout. This repo's
config uses:

- `startup_timeout_sec = 60`
- `tool_timeouts.deploy-local-folder = 600` (10 min for first deploy)

---

## Troubleshooting

| Symptom                                      | Fix                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `grok mcp doctor cloud-run` fails            | `gcloud auth application-default login`                                                               |
| MCP starts but deploy fails with auth error  | Re-run ADC login; confirm `GOOGLE_CLOUD_PROJECT`                                                      |
| Cold start / connection timeout              | Set `startup_timeout_sec = 60` in config                                                              |
| Deploy hangs or times out                    | Set `tool_timeouts = { deploy-local-folder = 600 }`                                                   |
| `Permission denied` on deploy                | Check IAM roles in [Prerequisites](#4-iam-roles)                                                      |
| Plugin MCP shows **blocked**                 | Reinstall with `grok plugin install ... --trust`                                                      |
| Plugin installed but tools missing           | `grok plugin enable cloud-run`                                                                        |
| `curl` returns 403                           | Service may not be public; check IAM or set `SKIP_IAM_CHECK=false` and add `allUsers` invoker binding |
| `curl` connection refused right after deploy | Wait 30–60s for the new revision to become ready, then retry                                          |

### Diagnostic commands

```bash
./scripts/verify-setup.sh          # full Phase 3 checklist
grok mcp doctor cloud-run          # MCP health
grok plugin validate .             # plugin manifest
grok inspect                       # skills, commands, hooks, MCP inventory
grok plugin list                   # installed plugins
gcloud auth application-default print-access-token  # confirm ADC
```

## Marketplace

Install from GitHub:

```bash
grok plugin install gprot42/grok-mcp-cloudrun --trust
grok plugin enable cloud-run
```

To submit to the official xAI marketplace, see [MARKETPLACE.md](MARKETPLACE.md).

---

## Project layout

```
grok-mcp-cloudrun/
├── .mcp.json                  # MCP server config (Grok primary)
├── .claude-plugin/plugin.json # Claude-ecosystem compat
├── .grok-plugin/plugin.json   # Marketplace manifest
├── plugin.json                # Plugin metadata
├── commands/
│   ├── deploy.md              # /deploy slash command
│   └── logs.md                # /logs slash command
├── hooks/hooks.json           # SessionStart + PreToolUse safety
├── skills/cloud-run/SKILL.md  # MCP-first Cloud Run workflow
├── LICENSE                    # Apache 2.0 (upstream)
├── NOTICE                     # Upstream attribution
└── README.md                  # This guide
```

---

## Hosted MCP vs local plugin

This plugin runs the MCP server **locally via stdio**
(`npx @google-cloud/cloud-run-mcp`). That is what powers `/deploy`, which calls
`cloud-run__deploy-local-folder` on your current working directory.

If you deploy the upstream MCP server itself to Cloud Run, it behaves
differently:

|                          | Local plugin (this repo) | Hosted on Cloud Run                   |
| ------------------------ | ------------------------ | ------------------------------------- |
| Transport                | stdio via `npx`          | `POST /mcp` or `GET /sse`             |
| `/deploy` (local folder) | Works                    | **Not available**                     |
| Deploy by file contents  | Yes                      | Yes                                   |
| Browser at service URL   | N/A                      | `Cannot GET /` (expected — no web UI) |

To verify a hosted MCP deployment, send an MCP `initialize` request to `/mcp`
(see [GROK-CHANGES.md](GROK-CHANGES.md#lessons-from-hosted-mcp-evaluation)).

For Grok day-to-day use, install this plugin — do not point Grok at a public
Cloud Run URL without IAM authentication.

---

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).

Upstream MCP server:
[GoogleCloudPlatform/cloud-run-mcp](https://github.com/GoogleCloudPlatform/cloud-run-mcp)
· npm: `@google-cloud/cloud-run-mcp@1.10.0`
