#!/usr/bin/env bash
set -euo pipefail
# Smoke test: version → create bank → retain → recall. Key never echoed.
source /home/deploy/ops/hindsight.env

KEY="$HINDSIGHT_API_TENANT_API_KEY"
API=http://127.0.0.1:8888
H1="Authorization: Bearer $KEY"

echo "=== version ==="
curl -s -H "$H1" "$API/version"; echo

echo "=== create bank 'living' ==="
curl -s -X PUT -H "$H1" -H 'Content-Type: application/json' \
  -d '{"enable_observations":true,"enable_temporal_retrieval":true,"enable_graph_retrieval":true,"enable_reranking":true}' \
  "$API/v1/default/banks/living"; echo

echo "=== retain ==="
curl -s -X POST -H "$H1" -H 'Content-Type: application/json' \
  -d '{"async":false,"items":[{"content":"Amihai is building a living memory for the 5qln language.","context":"5qln fractal memory smoke test"}]}' \
  "$API/v1/default/banks/living/memories"; echo

echo "=== recall ==="
curl -s -X POST -H "$H1" -H 'Content-Type: application/json' \
  -d '{"query":"What is Amihai building for 5qln?","budget":"mid"}' \
  "$API/v1/default/banks/living/memories/recall" | head -c 2500; echo
