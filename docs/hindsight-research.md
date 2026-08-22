# Hindsight — Research Findings (verified)

Condensed from the full research dossier. Every load-bearing fact below was **re-checked against primary sources** on 2026-08-22 before being trusted. The two corrections found during verification are called out.

## The tool

**Hindsight** (github.com/vectorize-io/hindsight) — an agent memory system: retain (save + extract), recall (find), reflect (reason). Self-hostable (Docker), ~20.9k stars, actively maintained, v0.9.1 (pre-1.0 — pin and upgrade deliberately).

## Verdicts per claim

| Claim | Verdict |
|---|---|
| Real, actively maintained, self-hostable | ✅ Partially — pre-1.0, "expect breaking changes", schema still in flux |
| Generic API/MCP surface for arbitrary agents | ✅ Supported — 29 MCP tools; HTTP API at `/v1/default/banks/{id}/...` |
| LiteLLM / DeepSeek backing | ✅ Supported — `deepseek`, `litellm`, `litellmrouter` are native LLM-provider values |
| Hermes native memory provider | ✅ Supported — `hermes memory setup` → hindsight; plugin in `NousResearch/hermes-agent` |
| Four-way retrieval (semantic+BM25+graph+temporal) | ✅ Supported — arxiv 2512.12818; RRF + cross-encoder reranking |
| Auto-consolidation can be constrained (trust boundary) | ⚠️ Partially — read-only is **per-bank**, not per-content |
| Memory Defense (secret redaction) | ⚠️ Partially — 45-pattern regex, scans **retain only**, opt-in |
| Free for self-hosted | ✅ Supported — permissive license (see correction) |

## Corrections found during verification (do not repeat the dossier's mistakes)

1. **License is MIT, not Apache 2.0.** The dossier claimed Apache 2.0; the GitHub API reports `spdx_id: MIT`. Low decision impact (MIT is more permissive), but a factual miss.
2. **"DeepSeek Harness" ≠ `pi`.** The coding-agents package lists *DeepSeek Harness* (`dsh`, the harness runtime), not `pi` (`@earendil-works/pi-coding-agent`, the coding CLI). The Pi agents integrate via **raw MCP/HTTP**, not the native plugin.

## Closed during build

- **DeepSeek structured output** (the dossier's open gap) — verified working: retain's fact extraction succeeded end-to-end against DeepSeek.
- **Auth gotcha** — Hindsight auth is disabled by default; the tenant-extension env var must be set.

## The one gap that matters for the design

Auto-consolidation operates **per-bank, not per-content**. So the trust boundary (sealed canon vs living memory) must be **two banks** (a read-only canonical bank + a writable living bank), and recall is per-bank (two recalls + client-side merge if both are needed in one turn).
