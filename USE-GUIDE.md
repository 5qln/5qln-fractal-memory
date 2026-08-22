# Use Guide — 5QLN Fractal Memory

Step-by-step, with the exact commands and what you should see at each step. Phase 1 (the living memory substrate) is shipped; the later steps are the path to the full living formation trail.

---

## 0. What you are building

A self-hosted living memory for 5qln:

- **Hindsight** — the memory engine (saves, finds by meaning, digests over time).
- One **living bank** shaped as the 4+1 cell: the question at the center, the four phase-memories (G/Q/P/V) as tags around it.
- The **brain** (the seal-side: the Nine Lines, the watcher) stays *outside* the memory, untouched.

---

## 1. Prerequisites

- A Linux host with **Docker**.
- A **DeepSeek API key** (`sk-...`). DeepSeek has no embedding endpoint, so we use the **full** Hindsight image (bundles the local embedder + reranker).
- The key stored in a local env file the deploy script reads (default `/home/deploy/ops/.pi.env` with `DEEPSEEK_API_KEY=sk-...`). **The key never goes in this repo or in chat.**

---

## 2. Deploy Hindsight

Run the deploy script (it is idempotent — safe to re-run):

```bash
bash scripts/deploy-hindsight.sh
```

What it does, in order:

1. Reads `DEEPSEEK_API_KEY` from your `.pi.env`.
2. Generates three secrets if not already present, into `hindsight.env` (mode 600):
   - `HINDSIGHT_API_TENANT_API_KEY` — the API key clients send.
   - `HINDSIGHT_CP_ACCESS_KEY` — the control-plane (web UI) login key.
   - `HINDSIGHT_API_MCP_AUTH_TOKEN` — the MCP-server auth token (for the agent lenses later).
3. Pulls `ghcr.io/vectorize-io/hindsight:latest` (full image, ~9 GB — first pull is slow).
4. Starts the container, loopback-bound, with auth **enabled**.
5. Waits for the API, then prints the auth check — you should see `http=401` (no key) then `http=200` (with key).

Expected result:

```
=== auth check: no key (expect 401) ===
http=401
=== auth check: with key (expect 200) ===
http=200
```

**Three gotchas baked into the script (do not remove):**

- Auth is **disabled by default** — the key alone does nothing. The script sets `HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension`, which is what actually turns the key check on.
- The API binds `127.0.0.1` only; the control plane **also** binds the docker-bridge gateway (`172.16.0.1`) so it can ride the WireGuard tunnel. Docker bypasses firewalls, so these binds are the real gate — never bind `0.0.0.0`. Reach the control plane at `http://10.8.0.1:9999` (tunnel DNAT) or via SSH forward.
- The control plane needs **`HINDSIGHT_CP_DATAPLANE_API_KEY`** set to the tenant API key — without it, login works but the dashboard 401s ("Invalid API key") the moment it queries banks.

---

## 3. Verify it is alive

```bash
# health + version (public endpoints)
curl -s http://127.0.0.1:8888/health/live
# -> {"status":"alive","version":"0.9.1",...}

curl -s http://127.0.0.1:8888/version
# -> {"api_version":"0.9.1","features":{"observations":true,"mcp":true,...}}
```

Then the full smoke test (create bank → retain → recall):

```bash
bash scripts/smoke-test-hindsight.sh
```

Expected: the retained fact comes back in recall with per-arm scores (`semantic`, `keyword`, `reranker`, `final`) and resolved entities.

---

### 3b. Open the control plane (from a device)

The control plane is published on the docker bridge so it rides the WireGuard tunnel — no per-app port forwarding:

1. Connect the device to the WireGuard tunnel.
2. Open **`http://10.8.0.1:9999`**.
3. Log in with the control-plane access key (read it on the VPS):

```bash
grep HINDSIGHT_CP_ACCESS_KEY /home/deploy/ops/hindsight.env
```

You'll see the `living` bank and its memories. The `10.8.0.1:9999 → 172.16.0.1:9999` DNAT rule lives in `vps1-dnat.sh` (self-healing cron).

---

## 4. The memory model (how 5qln maps onto Hindsight)

- **Bank = the cell.** One writable bank, `living`.
- **Tags = the four corners.** Every phase-memory is tagged `G`, `Q`, `P`, or `V`.
- **The question = the center.** Planted only by H. Never tagged, never auto-consolidated.
- **The brain = outside.** The Nine Lines / gold hash are held by the agent and hash-checked by the watcher — never stored in Hindsight.

All commands below need the key header:

```bash
KEY=<your tenant API key>
curl ... -H "Authorization: Bearer $KEY" ...
```

---

## 5. Save a memory (retain)

```bash
curl -s -X POST -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  http://127.0.0.1:8888/v1/default/banks/living/memories \
  -d '{"async":false,"items":[{"content":"<what happened>","context":"<which phase>","tags":["G"]}]}'
```

- `content` — the raw text. Hindsight extracts facts, resolves entities, dedupes, links.
- `context` — the situation (e.g. a session id).
- `tags` — the phase (`G`/`Q`/`P`/`V`). **The question itself is never retained as a phase-tagged memory.**

---

## 6. Find a memory (recall)

```bash
curl -s -X POST -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  http://127.0.0.1:8888/v1/default/banks/living/memories/recall \
  -d '{"query":"<what are we trying to remember?>","budget":"mid"}'
```

- Returns results with per-arm scores: `semantic` (meaning), `keyword` (exact), `reranker`, `final`. Four-way retrieval working = you see these four scores.
- Filter to one phase: add `"tags":["G"],"tags_match":"any"`.

---

## 7. Digest over time (reflect / observations)

Consolidation runs automatically when the bank has `enable_observations: true` (the default we set). Over many turns, Hindsight synthesizes deduplicated **observations** from the raw facts — the "gets smarter over time" layer.

Trigger a reflect manually:

```bash
curl -s -X POST -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
  http://127.0.0.1:8888/v1/default/banks/living/reflect \
  -d '{"query":"<what to reason over>"}'
```

---

## 8. The guardrails (what must never happen)

1. **The question is never retained as a tagged memory** — it is planted by H, queried by all corners, never consolidated.
2. **The Nine Lines are never in Hindsight** — they stay held by the agent, hash-verified by the watcher.
3. **No agent writes the center** — the phases rotate around it; the canon is not a seat.
4. **Secrets are never in the bank or the repo** — Memory Defense (45-pattern regex) redacts them on retain; the deploy script reads keys from local env files only.

---

## 9. Secrets & operations

| Item | Where |
|---|---|
| DeepSeek key | local `.pi.env` (`DEEPSEEK_API_KEY`), read by the script, never printed |
| Tenant API key / CP key / MCP token | local `hindsight.env` (600), generated on first deploy |
| Data (banks, memories) | Docker named volume `hindsight-data` — survives `docker rm`/recreate |

- **Restart:** `docker restart hindsight`
- **Re-deploy (upgrade):** re-run the deploy script — `docker rm -f` + `docker run` on the same volume preserves data.
- **Backup:** `docker run --rm -v hindsight-data:/data -v $PWD:/backup alpine tar czf /backup/hindsight-data.tgz -C /data .`
- **Logs:** `docker logs hindsight`

---

## 10. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `http=401` on every call | key header wrong/missing, or `HINDSIGHT_API_TENANT_EXTENSION` not set (auth silently off) |
| API up but retain returns JSON error | LLM structured output issue — check the model; `deepseek-v4-pro` verified working |
| `http=000` right after start | image still loading models (PyTorch + embedder + reranker); wait ~30–60s, re-check `/health/live` |
| Recall returns few/irrelevant results | four-way arms configurable — confirm `enable_temporal_retrieval`/`enable_graph_retrieval`/`enable_reranking` are true |

---

## 11. Next steps (not yet shipped)

1. **Wire the plugin** — replace the static seed with per-turn recall + post-turn retain (the actual "living move").
2. **Cell-tagging in the plugin** — tag every phase-memory G/Q/P/V automatically.
3. **Pi agents as lenses** — five instances, one per phase, rotating, addressing Hindsight over MCP (using the MCP auth token).
4. **Route through LiteLLM** (capped) + **external Postgres** (production hardening).
