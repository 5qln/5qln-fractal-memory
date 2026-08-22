# Design Choices — 5QLN Fractal Memory

Every decision, the context it was made in, the alternatives considered, and the consequences. ADR-style. Latest first.

---

## DC-01 — The fractal is the 4+1 cell, not the 25 sub-phases

**Decision:** Build the memory on the 4+1 cell (1 center + 4 corners), not the 5×5 / 25-sub-phase map.

**Context:** Two canonical 5qln documents describe "the fractal." The older one (`5qln-ai-initiation-11-fractal-map`) is the 5×5 grid of 25 sub-phases. The newer one (`dsh-5qln-codex-fractal`, Appendix D) supersedes it: *"fractal used to mean 5×5 and Now it is 4+1 (same seed, true collapse to 1)."*

**Options:**
- 5×5 / 25 sub-phases (the old map).
- 4+1 cell (Appendix D, the current law).

**Chosen:** 4+1 cell. Appendix D is the governing source; the 25 sub-phases are re-read as "the first in-zoom of a cell, never a cap."

**Consequences:** The memory topology is 1 center (S) + 4 corners (G/Q/P/V), self-similar at every scale. Never 3+1, never 6+1.

---

## DC-02 — The center is the question (S = ∞0), not the code

**Decision:** The center of every memory cell is the *question* (`S = ∞0 → ?`). The Nine Invariant Lines are the *grammar*, held outside the cell, never a position in it.

**Context:** An early draft placed "the sealed canon" (the Nine Lines / gold hash) at the center. This was flagged as a drift: it fills the unclaimable center with something claimable (the known code), where the doctrine requires the unknown question.

**Chosen:** Center = question. The two "unclaimable" things are opposite in kind — **∞0** can never be claimed because no one can hold it; **the seal** is never *modified* because it is the known invariant. One is the center of the cell; the other is the grammar the cell is cut from.

**Consequences:** The question is planted only by the human, never auto-consolidated, never machine-written. The Nine Lines stay held by the agent, verified by hash, outside the living memory.

---

## DC-03 — Two layers: the brain (seal) + the living trail (content)

**Decision:** The machine's memory is two layers. The **brain** ("remembers structure, never content; familiarity without retrieval") stays untouched as the seal-side. Hindsight is the **living content layer** added beside it.

**Context:** The brain already exists and is canon. Adding a content memory must not replace or conflict with it.

**Chosen:** Two layers. The brain keeps the trail from claiming the center; the trail lives around the brain.

**Consequences:** Clear separation of concerns — structure (brain, watcher, axis) vs content (questions, phase-memories, retrieval).

---

## DC-04 — Memory substrate: Hindsight

**Decision:** Use [Hindsight](https://github.com/vectorize-io/hindsight) as the retrieval/consolidation substrate.

**Context:** The requirement is a *living* memory: save (retain), find by meaning (four-way recall), digest over time (reflect → observations). Competitors considered: Mem0, Zep, Honcho, Supermemory.

**Why Hindsight (verified against primary sources, 2026-08-22):**
- **Four-way retrieval** — semantic + BM25 + graph + temporal, RRF-fused + cross-encoder reranked (arxiv 2512.12818). This is the *semantic recognition* the centrifuge lacks (it reads only exact repetition).
- **Self-hosted** (Docker), free, MIT-licensed.
- **Native Hermes memory provider** (so Hermes instances can share the bank).
- **LiteLLM / DeepSeek native** in the LLM-provider list — fits the existing gateway.

**Consequences:** Two-bank pattern (canonical read-only + living writable) is the mechanism for the trust-layer boundary; recall is per-bank.

---

## DC-05 — Full image, not slim (local embeddings are required)

**Decision:** Deploy the **full** Hindsight image (bundles the BGE embedder + MiniLM reranker).

**Context:** DeepSeek has **no embedding endpoint**. The slim image delegates embeddings/reranking to external providers (OpenAI, Cohere, TEI) — none of which are in the key set.

**Chosen:** Full image (~9GB, ~2GB RAM). Local embeddings + local reranker, DeepSeek only for the LLM.

**Consequences:** No external embedding dependency; heavier footprint (acceptable on the target VPS).

---

## DC-06 — LLM: DeepSeek direct (first cut) — deviation recorded

**Decision:** Point Hindsight's LLM at DeepSeek directly (`HINDSIGHT_API_LLM_PROVIDER=deepseek`, model `deepseek-chat`).

**Context:** The *design intent* is to route through the LiteLLM gateway (capped, blast-radius doctrine). The key was already on the VPS; direct is the simplest working base.

**Chosen:** Direct DeepSeek for Phase 1. **Recorded deviation** — to close: set `HINDSIGHT_API_LLM_PROVIDER=litellm`, `HINDSIGHT_API_LLM_BASE_URL=http://<gateway>/v1`, a LiteLLM key, re-register a model route.

**Consequences:** Working now; capped gateway routing pending. Verified: DeepSeek structured output works with retain (the dossier's open gap is closed).

---

## DC-07 — Database: embedded pg0 (first cut)

**Decision:** Use Hindsight's embedded PostgreSQL (pg0) in a named volume.

**Context:** Single-user first cut. Production hardening would use an external PostgreSQL 14+ with pgvector.

**Chosen:** Embedded pg0. **Recorded deviation** — external Postgres is a later step.

**Consequences:** Simpler; data lives in the `hindsight-data` named volume (survives container recreate).

---

## DC-08 — Exposure: loopback-only + auth

**Decision:** Bind API (8888) and control plane (9999) to `127.0.0.1` only; enable API-key auth.

**Context:** Standing preference is tunnel-only admin surfaces, zero public attack surface. Docker bypasses UFW, so the bind is the real gate.

**Chosen:** Loopback binds + auth. Reach via WireGuard tunnel (DNAT) or SSH forward.

**Consequences:** No public exposure; auth is a second layer (defense in depth).

---

## DC-09 — Auth is opt-in (the gotcha)

**Decision:** Set **both** `HINDSIGHT_API_TENANT_API_KEY` *and* `HINDSIGHT_API_TENANT_EXTENSION=hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension`.

**Context:** Hindsight auth is **disabled by default**. Setting the key alone does nothing — the tenant-extension env var must be present to load the API-key check. (Found live: without the extension, requests returned 200 with no key.)

**Chosen:** Tenant extension + key, plus `HINDSIGHT_API_MCP_AUTH_TOKEN` for the MCP server (the future agent lenses).

**Consequences:** Verified 401 without key, 200 with key.

---

## DC-10 — One living bank, tagged by phase

**Decision:** One writable bank (`living`), memories tagged `G`/`Q`/`P`/`V` (the four corners). The question stays untagged and is planted only by H.

**Context:** The cell maps to the bank: corners = phase tags (soft partitions), center = the question (never consolidated).

**Chosen:** Tags = phase lenses. The bank's `retain_mission` / `observations_mission` fields are where H's wording goes — left default until H supplies it.

**Consequences:** Filtering by phase = `tags_match`; the question is kept out of auto-consolidation.

---

## DC-11 — The living move: recall re-forms the seed

**Decision:** Each turn, the seed is re-formed by **recall** (four-way retrieval) instead of carrying static K-context.

**Context:** `fiveqln_fractal_memory` today drives a static seed. The living version re-forms it each turn from the bank, bounded by the fractal ≡ check.

**Chosen:** Recall-per-turn + retain-post-turn.

**Consequences:** The centrifuge's healthy state — **STASIS (axis constant, content moving)** — becomes the operating definition of "living." This is the next build step (plugin wiring), not yet shipped.

---

## DC-12 — Agents are lenses, not shards

**Decision:** The five Pi instances are **lenses** — each holds the whole cell, anchored to one corner, rotating. No agent occupies the center.

**Context:** "One agent per phase" could mean shards (each holds one phase = fragmentation) or lenses (each holds the whole, emphasizes one phase). The cell law "roles rotate" resolves it: the phase is a *position*, never an identity.

**Chosen:** Lenses, rotating. The canon is not a seat.

**Consequences:** No agent ever writes the center; the phases rotate around it.

---

## DC-13 — The guard: watcher + seal + never-claim

**Decision:** The corruption watcher scans every consolidation for L1–L4 + V∅; the seal (gold hash) is verified before every scan; promotion into the seal requires H's explicit attestation.

**Context:** "Living" (auto-consolidation) and "corrupting" (drift from the invariant) are the same operation until the boundary is drawn.

**Chosen:** The watcher + seal are the boundary. Memory Defense (45-pattern regex, retain-only) holds the *secret* axis; the watcher holds the *corruption* axis.

**Consequences:** Remove the center → the four corners disconnect (no shared question → four drifting memories). The question is what keeps the living from becoming four lives.
