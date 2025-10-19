# Changelog

## 2025-10-19 — v1.5 (plan) & v1.4 wrap-up
- Added host-side CLI tools with streaming output: `devask_h`, `devteach_h`, `devnote_h`.
- Documented Docker-based setup and healthcheck removal for stability.
- Created Self-check script (`devcli_selfcheck`, v1.5 "Reliquary") to verify:
  - Ollama API reachability and streaming JSON
  - Presence of host tools
  - Repo write path and optional push
- Uploaded Troubleshooting Notes (Markdown + PDF) to `docs/troubleshooting/`.
- Time spent (approx): 3.5–4.5 hours (builds, pulls, debugging streams, scripting).

### Next (v1.5 "Reliquary")
- Unify streaming parser across container tools.
- Add `_wait_ollama` readiness helper.
- Merge persona options under a single tool.
- Add a smoke-test command and CI job to catch regressions.
