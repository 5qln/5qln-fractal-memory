#!/usr/bin/env bash
set -euo pipefail
# Hindsight deploy — full image, DeepSeek LLM, embedded pg0, API-key auth ENABLED.

source /home/deploy/ops/.pi.env
[ -n "${DEEPSEEK_API_KEY:-}" ] || { echo "ERR: no DEEPSEEK_API_KEY"; exit 1; }

STORE=/home/deploy/ops/hindsight.env
if [ ! -f "$STORE" ]; then
  umask 077
  printf 'HINDSIGHT_API_TENANT_API_KEY=%s\nHINDSIGHT_CP_ACCESS_KEY=%s\nHINDSIGHT_API_MCP_AUTH_TOKEN=%s\n' \
    "$(openssl rand -hex 32)" "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > "$STORE"
else
  grep -q '^HINDSIGHT_API_MCP_AUTH_TOKEN=' "$STORE" || printf 'HINDSIGHT_API_MCP_AUTH_TOKEN=%s\n' "$(openssl rand -hex 32)" >> "$STORE"
fi
# shellcheck disable=SC1091
source "$STORE"

docker rm -f hindsight 2>/dev/null || true

echo "starting ..."
docker run -d \
  --name hindsight \
  --restart unless-stopped \
  -p 127.0.0.1:8888:8888 \
  -p 127.0.0.1:9999:9999 \
  -p 172.16.0.1:9999:9999 \
  -e HINDSIGHT_API_LLM_PROVIDER=deepseek \
  -e HINDSIGHT_API_LLM_API_KEY="$DEEPSEEK_API_KEY" \
  -e HINDSIGHT_API_LLM_MODEL=deepseek-chat \
  -e HINDSIGHT_API_LLM_BASE_URL=https://api.deepseek.com \
  -e HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension \
  -e HINDSIGHT_API_TENANT_API_KEY="$HINDSIGHT_API_TENANT_API_KEY" \
  -e HINDSIGHT_CP_ACCESS_KEY="$HINDSIGHT_CP_ACCESS_KEY" \
  -e HINDSIGHT_CP_DATAPLANE_API_URL=http://127.0.0.1:8888 \
  -e HINDSIGHT_CP_DATAPLANE_API_KEY="$HINDSIGHT_API_TENANT_API_KEY" \
  -e HINDSIGHT_API_MCP_AUTH_TOKEN="$HINDSIGHT_API_MCP_AUTH_TOKEN" \
  -e HINDSIGHT_API_WORKER_ID=hindsight-prod \
  -v hindsight-data:/home/hindsight/.pg0 \
  ghcr.io/vectorize-io/hindsight:latest

echo "waiting for API ..."
for i in $(seq 1 24); do
  sleep 5
  if curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8888/health/live 2>/dev/null | grep -q 200; then
    echo "API up after $((i*5))s"; break
  fi
done

echo "=== auth check: no key (expect 401) ==="
curl -s -o /dev/null -w 'http=%{http_code}\n' http://127.0.0.1:8888/v1/default/banks
echo "=== auth check: with key (expect 200) ==="
curl -s -o /dev/null -w 'http=%{http_code}\n' -H "Authorization: Bearer $HINDSIGHT_API_TENANT_API_KEY" http://127.0.0.1:8888/v1/default/banks
echo "=== banks (with key) ==="
curl -s -H "Authorization: Bearer $HINDSIGHT_API_TENANT_API_KEY" http://127.0.0.1:8888/v1/default/banks; echo
