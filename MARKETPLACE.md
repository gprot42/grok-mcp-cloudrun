# xAI Marketplace Submission

This plugin can be installed directly from GitHub today:

```bash
grok plugin install gprot42/grok-mcp-cloudrun --trust
grok plugin enable cloud-run
```

To list it in the official
[xAI Plugin Marketplace](https://github.com/xai-org/plugin-marketplace), submit
a PR to that catalog repo.

## Prerequisites

- Plugin source is public: https://github.com/gprot42/grok-mcp-cloudrun
- `grok plugin validate` passes
- `scripts/verify-setup.sh` passes locally
- Version tagged in `plugin.json` (use `grok plugin tag --push`)

## Catalog entry

Add this object to `.grok-plugin/marketplace.json` in
`xai-org/plugin-marketplace`:

```json
{
  "name": "cloud-run",
  "description": "Deploy and manage Google Cloud Run services from Grok. MCP tools, /deploy and /logs slash commands, safety hooks. Wraps @google-cloud/cloud-run-mcp (not affiliated with Google).",
  "category": "deployment",
  "source": {
    "source": "url",
    "url": "https://github.com/gprot42/grok-mcp-cloudrun.git",
    "sha": "REPLACE_WITH_RELEASE_COMMIT_SHA"
  },
  "homepage": "https://github.com/gprot42/grok-mcp-cloudrun",
  "keywords": ["cloud run mcp", "grok cloud run", "google cloud run grok"],
  "domains": ["cloud.google.com", "console.cloud.google.com"]
}
```

Pin the full 40-character lowercase commit SHA from a release tag:

```bash
git ls-remote https://github.com/gprot42/grok-mcp-cloudrun.git refs/tags/v0.2.0
```

## Submission steps

1. Fork https://github.com/xai-org/plugin-marketplace
2. Add the catalog entry above (replace `sha`)
3. Regenerate the component index:
   ```bash
   python3 scripts/generate-plugin-index.py
   ```
4. Validate:
   ```bash
   python3 scripts/validate-catalog.py
   python3 scripts/generate-plugin-index.py --check
   ```
5. Open a PR using the repo template

## Review notes

- **License:** Apache 2.0 with upstream attribution in `NOTICE`
- **Not affiliated with Google** — stated in README and plugin description
- **Hooks:** `SessionStart` warns on missing project/ADC; `PreToolUse` blocks
  `create-project` and production-like deploys unless explicitly confirmed
- **MCP:** stdio via `npx @google-cloud/cloud-run-mcp@1.10.0` (pinned)
- **Keywords:** brand-scoped for Cloud Run + Grok (not generic `deploy` alone)
