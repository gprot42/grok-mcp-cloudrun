# Grok MCP Changes

This document records what was added or adapted to make
[Google's Cloud Run MCP server](https://github.com/GoogleCloudPlatform/cloud-run-mcp)
work well in [Grok](https://github.com/xai-org/grok).

**This repo is a Grok plugin wrapper, not a fork of the upstream MCP server.**
The server itself is still launched via
`npx @google-cloud/cloud-run-mcp@1.10.0`.

---

## What this repo adds

| Addition               | Path                                      | Purpose                                                     |
| ---------------------- | ----------------------------------------- | ----------------------------------------------------------- |
| Grok plugin manifest   | `plugin.json`, `.grok-plugin/plugin.json` | Marketplace metadata and install identity                   |
| MCP server config      | `.mcp.json`                               | Spawns upstream MCP via `npx` with env passthrough          |
| Claude-compat manifest | `.claude-plugin/plugin.json`              | Ecosystem compatibility                                     |
| Cloud Run skill        | `skills/cloud-run/SKILL.md`               | Grok-specific MCP-first workflow + gcloud fallback          |
| Deploy slash command   | `commands/deploy.md`                      | `/deploy [service-name]` → `cloud-run__deploy-local-folder` |
| Logs slash command     | `commands/logs.md`                        | `/logs [service-name]` → `cloud-run__get-service-log`       |
| Safety hooks           | `hooks/hooks.json`                        | Warn on missing project; block `create-project` by default  |
| Setup guide            | `README.md`                               | Grok install, auth, smoke test, troubleshooting             |
| Implementation plan    | `PLAN-cloudrun-grok-mcp.md`               | Original design and phase breakdown                         |
| Attribution            | `NOTICE`                                  | Upstream license and non-affiliation statement              |

---

## Grok-specific adaptations

### 1. MCP tool naming

Grok namespaces MCP tools as `cloud-run__<tool>`. The skill and slash commands
reference:

- `cloud-run__deploy-local-folder`
- `cloud-run__list-services`
- `cloud-run__get-service`
- `cloud-run__get-service-log`
- `cloud-run__list-projects`
- `cloud-run__create-project`

### 2. Skill rewritten for Grok

Upstream `skills/cloud-run/SKILL.md` (in the Google repo) targets Gemini CLI and
generic agents. This repo's skill adds:

- Grok prerequisite checks (`/mcps` shows `cloud-run`)
- MCP-first tool table mapped to Grok namespaced tools
- Explicit `/deploy` and `/logs` slash command triggers
- `gcloud run` fallback when MCP is unavailable
- Safety note for `create-project` and `SKIP_IAM_CHECK`

### 3. Slash commands

| Command          | Resolves service name as                    | MCP tool                         |
| ---------------- | ------------------------------------------- | -------------------------------- |
| `/deploy [name]` | arg → `DEFAULT_SERVICE_NAME` → cwd basename | `cloud-run__deploy-local-folder` |
| `/logs [name]`   | arg → `DEFAULT_SERVICE_NAME` → cwd basename | `cloud-run__get-service-log`     |

Both commands document prerequisite checks and error handling tables for common
auth/IAM failures.

### 4. Safety hooks

**SessionStart** — warns when neither `GOOGLE_CLOUD_PROJECT` nor a `gcloud`
default project is configured.

**PreToolUse** — blocks `cloud-run__create-project` unless
`CONFIRM_CLOUD_RUN_CREATE_PROJECT=1` is set, because it creates billable GCP
resources.

### 5. Pinned upstream version

`.mcp.json` pins `@google-cloud/cloud-run-mcp@1.10.0` to avoid surprise breakage
from `@latest`.

Recommended Grok config also sets:

- `startup_timeout_sec = 60` (cold `npx` downloads)
- `tool_timeouts.deploy-local-folder = 600` (first deploy can take several
  minutes)

### 6. gcloud fallback

When the MCP server is not connected in a Grok session, agents should fall back
to:

```bash
gcloud run deploy SERVICE --source . --project PROJECT --region REGION
```

This was validated during initial testing when `CallMcpTool` could not reach the
local MCP server but Application Default Credentials were available.

---

## Lessons from hosted MCP evaluation

During smoke testing, the upstream MCP server itself was deployed to Cloud Run
as `hello-test`. Findings documented here for Grok users:

### Local vs hosted tool sets

| Mode                          | `deploy-local-folder` | Other deploy tools                                    |
| ----------------------------- | --------------------- | ----------------------------------------------------- |
| **Local stdio** (Grok plugin) | Available             | All tools                                             |
| **Hosted on Cloud Run**       | Not available         | `deploy-file-contents`, `deploy-container-image` only |

**Implication for Grok:** `/deploy` requires the **local** MCP server (this
plugin's stdio path). Deploying the MCP server to Cloud Run does not replace
local `/deploy` — the hosted instance cannot read your project folder.

### Browser shows `Cannot GET /`

The upstream MCP server exposes protocol endpoints (`POST /mcp`, `GET /sse`),
not a web UI. Opening the Cloud Run service URL in a browser returns
`Cannot GET /` — this is expected.

Verify a hosted deployment with:

```bash
curl -X POST https://SERVICE_URL/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}},"id":1}'
```

### Auth gotcha

`gcloud auth login` credentials can expire independently of Application Default
Credentials. If `gcloud run deploy` fails with "Reauthentication failed", either
run `gcloud auth login` or use ADC:

```bash
export CLOUDSDK_AUTH_ACCESS_TOKEN=$(gcloud auth application-default print-access-token)
gcloud run deploy ...
```

---

## What was intentionally not changed

Per `PLAN-cloudrun-grok-mcp.md`:

- No fork of `@google-cloud/cloud-run-mcp` source
- No OAuth-mode MCP wiring (Gemini-specific flow deferred)
- Remote MCP via `gcloud run services proxy` deferred to a later phase
- No Google trademark or official-partnership implication

---

## Upstream references

- MCP server: https://github.com/GoogleCloudPlatform/cloud-run-mcp
- npm: `@google-cloud/cloud-run-mcp@1.10.0`
- License: Apache 2.0
- Grok MCP docs:
  https://github.com/xai-org/grok/blob/main/docs/user-guide/07-mcp-servers.md
- Grok plugin docs:
  https://github.com/xai-org/grok/blob/main/docs/user-guide/09-plugins.md
