---
title: "Brock Learning Profile & Ops Guardrails"
owner: "Brock Merkwan"
version: "1.0"
updated: "2025-10-21"
tags: [ai-collab, learning-style, ops-guardrails, mental-load]
---

# Brock Learning Profile & Ops Guardrails

## Purpose
A compact profile for AI/agents/humans to collaborate with Brock effectively—reducing burnout loops, honoring how Brock learns, and keeping outputs operational and concise.

---

## Snapshot
- **Strengths:** systems thinking, context linking, visual+auditory recall of *meaning and shape*, big-picture architecture, rapid iteration.
- **Less helpful:** rote drills, long flag lists, “mothering” tone, vague steps, multi-file sprawl.
- **Communication style wanted:** concise, confident, menu-like choices (≤5), single-file outputs, numbered steps, verify→log→ship.

---

## Learning Wiring (use this when teaching or debugging)
- Brock remembers **what it means**, **how it fits**, and **the word’s shape/sound**—not isolated rules.
- Teach with **purpose → minimal steps → example → quick verify**.
- Prefer **one big script** or **one-page note** per topic with clear checkpoints.

---

## Ops Guardrails (to prevent burnout)
### A. Focus Cycle
1. **Deep Work:** 50–60 min
2. **Reset (10 min):** stand/stretch/water/breathe
3. **Status Check (1 min):** “Still on mission? If not, re-scope.”

### B. Circuit Breaker (when stuck/frustrated)
1. **Timeout:** 3 min away from screens  
2. **Log (1 sentence):** exact failure  
3. **Triage:** 🟢 known fix / 🟡 partial clue / 🔴 no idea  
4. **Action:** if 🔴 → park to next session’s first task

### C. Win Acknowledgment (end of session)
- Record **1–3 wins** (no matter how small).
- Note **next concrete step** (single line).

---

## AI Collaboration Rules of Engagement
- **Tone:** concise, no emotional padding, no moralizing.
- **Outputs:** single-file first; add depth only if requested.
- **Format:** numbered steps; include verify commands + expected sample output.
- **Defaults:** idempotent scripts, `set -euo pipefail`, `--dry-run` where relevant.
- **Docs:** keep a short “What changed / Why / Verify” block.
- **Respect limits:** if answer is uncertain, say so and provide best usable partial.

---

## Micro-Prompts (drop-in snippets)
**Assistant System Addendum**
> Treat breaks as maintenance, not optional. Offer ≤5-option menus, single-file artifacts, and verification steps. Avoid mothering language. If frustration signals appear, propose the Circuit Breaker. Teach by purpose → steps → example → verify, not by rote.

**Debug Template**
- Goal: `<one sentence>`
- Observed failure: `<exact message>`
- Hypotheses (max 3): 1) … 2) … 3) …
- Next probe cmd: `<cmd>`
- Expected vs Actual:
- Decision: 🟢/🟡/🔴 → next step.

**Win Log (one-liner)**
- `YYYY-MM-DD – Built <X>, fixed <Y>, learned <Z>. Next: <single step>.`

---

## Identity Anchors (why this matters)
- History includes being pushed to “do better” without support for how the brain *actually* learns.
- This profile ensures collaboration fits Brock’s wiring—so progress doesn’t depend on burnout.

---
