#!/usr/bin/env bash
# Phase 3 testing checklist — run locally before release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ! $1"; WARN=$((WARN + 1)); }

echo "=== grok-mcp-cloudrun verify-setup ==="
echo

echo "1. Plugin manifest"
if grok plugin validate . >/dev/null 2>&1; then
  pass "grok plugin validate"
else
  fail "grok plugin validate"
fi

echo
echo "2. MCP connectivity"
if grok mcp doctor cloud-run >/dev/null 2>&1; then
  pass "grok mcp doctor cloud-run"
else
  fail "grok mcp doctor cloud-run"
fi

echo
echo "3. Prerequisites"
if command -v gcloud >/dev/null 2>&1; then
  pass "gcloud CLI installed"
else
  fail "gcloud CLI installed"
fi

if gcloud auth application-default print-access-token >/dev/null 2>&1; then
  pass "Application Default Credentials configured"
else
  fail "Application Default Credentials configured"
fi

PROJECT="${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
if [ -n "$PROJECT" ]; then
  pass "GCP project resolved ($PROJECT)"
else
  fail "GCP project resolved"
fi

REGION="${GOOGLE_CLOUD_REGION:-us-central1}"
echo
echo "4. Cloud Run list services (gcloud fallback)"
if gcloud run services list --project="$PROJECT" --region="$REGION" --format='value(metadata.name)' >/dev/null 2>&1; then
  pass "gcloud run services list"
else
  warn "gcloud run services list (check IAM or APIs)"
fi

echo
echo "5. Lint"
if npm run lint:check >/dev/null 2>&1; then
  pass "prettier lint:check"
else
  fail "prettier lint:check"
fi

echo
echo "6. Safety hooks present"
if [ -f hooks/hooks.json ] && grep -q 'CONFIRM_CLOUD_RUN_CREATE_PROJECT' hooks/hooks.json; then
  pass "create-project guard hook"
else
  fail "create-project guard hook"
fi

if grep -q 'CONFIRM_CLOUD_RUN_PROD_DEPLOY' hooks/hooks.json; then
  pass "production deploy guard hook"
else
  fail "production deploy guard hook"
fi

echo
echo "=== Summary: $PASS passed, $FAIL failed, $WARN warnings ==="
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi