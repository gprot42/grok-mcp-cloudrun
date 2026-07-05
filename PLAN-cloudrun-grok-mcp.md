# Cloud Run MCP for Grok — Implementation Plan

**Goal:** Make
[GoogleCloudPlatform/cloud-run-mcp](https://github.com/GoogleCloudPlatform/cloud-run-mcp)
work in Grok with minimal friction — first as a configured MCP server, then
optionally as a Grok plugin with skill and slash commands.

**Upstream:** `@google-cloud/cloud-run-mcp` (Apache 2.0)  
**Grok docs:**
[MCP servers](https://github.com/xai-org/grok/blob/main/docs/user-guide/07-mcp-servers.md)
·
[Plugins](https://github.com/xai-org/grok/blob/main/docs/user-guide/09-plugins.md)

---

## 1. Scope

| In scope                                              | Out of scope (v1)                                 |
| ----------------------------------------------------- | ------------------------------------------------- |
| Local stdio MCP via `npx @google-cloud/cloud-run-mcp` | Forking or rewriting the upstream MCP server      |
| Grok `config.toml` / `grok mcp add` setup             | Hosting the MCP server on Cloud Run (remote mode) |
| Optional Grok plugin wrapper                          | OAuth-mode MCP (Gemini-specific flow)             |
| Copy/adapt `skills/cloud-run/SKILL.md`                | Implying Google official endorsement              |
| `/deploy` and `/logs` Grok slash commands             | Full GCP console parity                           |

---

## 2. License & compliance

The upstream repo is **Apache License 2.0**. This allows use, modification, and
redistribution.

### Allowed without extra paperwork

- Personal `config.toml` pointing at `npx -y @google-cloud/cloud-run-mcp`
- Using tools (`deploy-local-folder`, `list-services`, etc.) in Grok sessions

### Required if we ship a Grok plugin

1. Include `LICENSE` (Apache 2.0) in the plugin repo
2. Add `NOTICE` / attribution in `README.md` and `plugin.json`
3. Mark modified files if we edit upstream source or skill text
4. Do **not** use Google trademarks to imply official partnership

**Separate concern:** Using the MCP to deploy invokes **Google Cloud services**
(billing, IAM, GCP Terms). That is cloud usage, not a license blocker on the
software.

---

## 3. Architecture

The upstream project is **two layers**, not one:

```
┌─────────────────────────────────────────────────────────┐
│  Grok Plugin (optional wrapper we build)                │
│  ├── .mcp.json          → spawns MCP server             │
│  ├── skills/cloud-run/  → workflow instructions         │
│  ├── commands/deploy.md → slash command shortcut        │
│  └── plugin.json        → manifest + metadata           │
└──────────────────────────┬──────────────────────────────┘
                           │ stdio
┌──────────────────────────▼──────────────────────────────┐
│  @google-cloud/cloud-run-mcp  (upstream, unchanged)     │
│  Tools: deploy-local-folder, list-services, get-log, …  │
└──────────────────────────┬──────────────────────────────┘
                           │ gcloud / GCP APIs
┌──────────────────────────▼──────────────────────────────┐
│  Google Cloud Run                                       │
└─────────────────────────────────────────────────────────┘
```

| Component                     | Type           | Owner                            |
| ----------------------------- | -------------- | -------------------------------- |
| `@google-cloud/cloud-run-mcp` | **MCP server** | Google (upstream)                |
| `skills/cloud-run/SKILL.md`   | **Skill**      | Google (upstream, optional copy) |
| Grok plugin directory         | **Plugin**     | Us (thin wrapper)                |

**Rule:** The MCP server does the work. The skill teaches _when and how_. The
plugin bundles both for one-click install.

---

## 4. Prerequisites

Install and authenticate before any MCP testing:

```bash
# Google Cloud SDK
gcloud auth login
gcloud auth application-default login

# Defaults (adjust)
gcloud config set project YOUR_PROJECT_ID
export GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID
export GOOGLE_CLOUD_REGION=us-central1
```

Also required:

- Node.js LTS (for `npx`)
- IAM permissions to deploy/list Cloud Run services in the target project

---

## 5. Implementation phases

### Phase 0 — Smoke test (30 min, no new repo)

Validate upstream works in Grok before building a plugin.

```bash
grok mcp add cloud-run \
  -e GOOGLE_CLOUD_PROJECT=YOUR_PROJECT_ID \
  -e GOOGLE_CLOUD_REGION=us-central1 \
  -- npx -y @google-cloud/cloud-run-mcp
```

**Verify:**

```bash
grok mcp doctor cloud-run
```

In a Grok session (`/mcps`):

- Server shows as enabled
- Tools appear: `deploy-local-folder`, `list-services`, `get-service`,
  `get-service-log`, `list-projects`, …

**Manual test prompts:**

1. "List Cloud Run services in project X region Y"
2. "Deploy the current folder to Cloud Run as service `hello-test`"
3. "Get logs for service `hello-test`"

**Exit criteria:** All three complete without MCP connection errors.

---

### Phase 1 — User config (1 hour)

Add durable config to `~/.grok/config.toml`:

```toml
[mcp_servers.cloud-run]
command = "npx"
args = ["-y", "@google-cloud/cloud-run-mcp"]
env = {
  GOOGLE_CLOUD_PROJECT = "${GOOGLE_CLOUD_PROJECT}",
  GOOGLE_CLOUD_REGION  = "${GOOGLE_CLOUD_REGION:-us-central1}",
  DEFAULT_SERVICE_NAME = "${DEFAULT_SERVICE_NAME:-}"
}
startup_timeout_sec = 60
enabled = true
```

Optional project-scoped override in `.grok/config.toml` (per-repo service name).

**Exit criteria:** Survives Grok restart; `/mcps` shows server without
re-adding.

---

### Phase 2 — Grok plugin scaffold (2–4 hours)

Create a new repo or directory (suggested name: `cloud-run-grok-plugin`).

```
cloud-run-grok-plugin/
├── LICENSE                    # Apache 2.0 (upstream) + our additions if any
├── README.md                  # install, auth, attribution
├── plugin.json                # Grok manifest
├── .mcp.json                  # MCP server config
├── commands/
│   ├── deploy.md              # /deploy slash command
│   └── logs.md                # /logs slash command
└── skills/
    └── cloud-run/
        └── SKILL.md           # copied from upstream, lightly adapted
```

#### `plugin.json` (draft)

```json
{
  "name": "cloud-run",
  "version": "0.1.0",
  "description": "Deploy and manage Google Cloud Run services from Grok. Wraps @google-cloud/cloud-run-mcp.",
  "author": { "name": "Your Name / Org" },
  "keywords": ["cloud-run", "gcp", "deploy", "google-cloud"],
  "license": "Apache-2.0",
  "repository": "https://github.com/YOUR_ORG/cloud-run-grok-plugin",
  "mcpServers": {
    "cloud-run": {
      "command": "npx",
      "args": ["-y", "@google-cloud/cloud-run-mcp"],
      "env": {
        "GOOGLE_CLOUD_PROJECT": "${GOOGLE_CLOUD_PROJECT}",
        "GOOGLE_CLOUD_REGION": "${GOOGLE_CLOUD_REGION:-us-central1}"
      }
    }
  }
}
```

#### `commands/deploy.md` (draft intent)

Mirror Gemini's `/deploy` behavior:

- Default service name: `DEFAULT_SERVICE_NAME` env → current directory name
- Invoke `deploy-local-folder` MCP tool on cwd
- Return deployed URL

#### Skill adaptation

Copy
[upstream SKILL.md](https://github.com/GoogleCloudPlatform/cloud-run-mcp/blob/main/skills/cloud-run/SKILL.md)
and add Grok-specific notes:

- Trigger phrases: "deploy to Cloud Run", "Cloud Run logs", "list Cloud Run
  services"
- Prerequisite checks: `gcloud auth`, `GOOGLE_CLOUD_PROJECT` set
- Prefer MCP tools for deploy/logs; fall back to `gcloud run` per skill tables

**Install locally:**

```bash
# In Grok TUI
/plugins → Add → /path/to/cloud-run-grok-plugin
```

Or copy to `~/.grok/plugins/cloud-run/`.

**Exit criteria:** Plugin loads in `/plugins`; MCP tools and skills both
visible.

---

### Phase 3 — Hardening (2–3 hours)

| Task               | Detail                                                                           |
| ------------------ | -------------------------------------------------------------------------------- |
| **Error messages** | Document common failures: ADC not set, wrong project, IAM denied                 |
| **Safety hook**    | Optional `PreToolUse` hook: confirm before `create-project` or production deploy |
| **Env validation** | `SessionStart` hook: warn if `GOOGLE_CLOUD_PROJECT` unset                        |
| **Timeouts**       | `startup_timeout_sec = 60` for cold `npx` downloads                              |
| **Docs**           | README: auth steps, example prompts, license attribution                         |

**Optional hook** (`hooks/hooks.json`):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "test -n \"$GOOGLE_CLOUD_PROJECT\" || echo 'WARN: GOOGLE_CLOUD_PROJECT not set — Cloud Run MCP may fail'"
          }
        ]
      }
    ]
  }
}
```

---

### Phase 4 — Marketplace publish (optional, 1–2 days)

Only if we want public distribution:

1. Push plugin repo to GitHub
2. Submit to xAI marketplace (or host as git-based plugin source)
3. README must include upstream attribution and Apache 2.0 license
4. Avoid "Official Google" naming — use "Cloud Run deploy for Grok (based on
   Google's MCP server)"

**Exit criteria:** Installable via `/marketplace` or `/plugins add owner/repo`.

---

## 6. MCP tools reference

From upstream README — what Grok gains:

| Tool                   | Local only? | Purpose                         |
| ---------------------- | ----------- | ------------------------------- |
| `deploy-local-folder`  | Yes         | Deploy cwd to Cloud Run         |
| `deploy-file-contents` | No          | Deploy files by content         |
| `list-services`        | No          | List services in project/region |
| `get-service`          | No          | Service details + URL           |
| `get-service-log`      | No          | Logs and errors                 |
| `list-projects`        | Yes         | List GCP projects               |
| `create-project`       | Yes         | Create project + attach billing |

**Prompts** (MCP-level shortcuts, not Grok slash commands): `deploy`, `logs`.

---

## 7. Testing checklist

| #   | Test                             | Expected                            |
| --- | -------------------------------- | ----------------------------------- |
| 1   | `grok mcp doctor cloud-run`      | Healthy connection                  |
| 2   | List services (existing project) | Returns service list or empty array |
| 3   | Deploy sample app                | Returns public HTTPS URL            |
| 4   | `get-service-log` after deploy   | Recent log lines                    |
| 5   | Grok restart                     | MCP reconnects without manual steps |
| 6   | Plugin disable/enable            | Tools disappear/reappear in `/mcps` |
| 7   | Missing ADC                      | Clear auth error, not silent hang   |

**Sample app for deploy tests:** use upstream `example-sources-to-deploy/` from
the Google repo.

---

## 8. Risks & mitigations

| Risk                                        | Mitigation                                                          |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Cold `npx` startup timeout                  | `startup_timeout_sec = 60`; pin package version after first success |
| Accidental prod deploy                      | `PreToolUse` confirmation hook; default to non-prod project         |
| `create-project` creates billable resources | Document danger; optional hook to block tool                        |
| Credential expiry                           | README: re-run `gcloud auth application-default login`              |
| Upstream breaking changes                   | Pin `@google-cloud/cloud-run-mcp@X.Y.Z` in plugin args              |
| License violation on publish                | Ship LICENSE + attribution; legal review if commercial              |

---

## 9. Remote MCP mode (deferred)

Upstream supports hosting the MCP server on Cloud Run with IAM auth + local
proxy:

```bash
gcloud run services proxy cloud-run-mcp --port=3000 --region=REGION
```

Grok config would use:

```toml
[mcp_servers.cloud-run]
url = "http://localhost:3000/sse"
```

Defer until local stdio path is stable. Remote mode adds proxy lifecycle
management and OAuth edge cases.

---

## 10. Effort summary

| Phase               | Effort   | Deliverable                              |
| ------------------- | -------- | ---------------------------------------- |
| 0 — Smoke test      | 30 min   | Confirmed Grok + upstream MCP works      |
| 1 — User config     | 1 hr     | `config.toml` entry                      |
| 2 — Plugin scaffold | 2–4 hr   | Installable plugin with skill + commands |
| 3 — Hardening       | 2–3 hr   | Hooks, docs, error handling              |
| 4 — Marketplace     | 1–2 days | Public plugin (optional)                 |

**Minimum viable:** Phase 0 + Phase 1 (under 2 hours).  
**Recommended:** Through Phase 3 (~1 day).  
**Full product:** Phase 4 if sharing with others.

---

## 11. Decision log

| Decision               | Choice                                      | Rationale                                          |
| ---------------------- | ------------------------------------------- | -------------------------------------------------- |
| Fork upstream?         | No                                          | Apache 2.0 allows wrapping; `npx` keeps us current |
| MCP vs skill only?     | Both                                        | MCP = tools; skill = workflow discipline           |
| stdio vs remote?       | stdio first                                 | Simpler auth (ADC), matches Gemini local setup     |
| Plugin vs config-only? | Plugin for sharing; config for personal use | Plugin adds slash commands + marketplace path      |
| Pin version?           | Yes after smoke test                        | Avoid surprise breakage from `@latest`             |

---

## 12. Implementation status

| Phase               | Status      | Notes                                                                     |
| ------------------- | ----------- | ------------------------------------------------------------------------- |
| 0 — Smoke test      | Done        | `grok mcp doctor cloud-run` passes; deploy/logs validated                 |
| 1 — User config     | Done        | `~/.grok/config.toml` configured                                          |
| 2 — Plugin scaffold | Done        | https://github.com/gprot42/grok-mcp-cloudrun                              |
| 3 — Hardening       | Done        | Hooks, timeouts in `.mcp.json`, `scripts/verify-setup.sh`, CI             |
| 4 — Marketplace     | In progress | GitHub install ready; xAI catalog PR via [MARKETPLACE.md](MARKETPLACE.md) |

## 13. Next actions

1. Run `./scripts/verify-setup.sh` before each release
2. Tag releases: `grok plugin tag --push`
3. Submit marketplace PR to `xai-org/plugin-marketplace` (see MARKETPLACE.md)

---

## References

- Upstream repo: https://github.com/GoogleCloudPlatform/cloud-run-mcp
- npm package: `@google-cloud/cloud-run-mcp`
- License: Apache 2.0 (see upstream `LICENSE`)
- Gemini extension config: `gemini-extension.json` in upstream repo
- Grok plugin examples: `~/.grok/installed-plugins/chrome-devtools-mcp-*`,
  `sentry-for-ai-*`
