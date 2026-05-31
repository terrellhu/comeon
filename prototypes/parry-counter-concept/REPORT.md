# Concept Prototype Report: 刃响 — Parry Counter System

> **Date**: 2026-05-31
> **Prototype Path**: Engine (Godot 4.6, GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player times a parry button press within the visual-telegraph window (boss glows bright orange), the resulting counter-attack will feel satisfying enough that they voluntarily retry the pattern 3+ times without being asked to.

---

## Riskiest Assumption Tested

**Parry timing window width** — the single hardest design parameter in any parry system. Too wide = trivial, no satisfaction. Too narrow = pure luck, frustration.

Default tested values:
- `TELEGRAPH_DURATION` = 1.0s
- `PARRY_WINDOW_START` = 0.50 (window opens at 50% of telegraph)
- `PARRY_WINDOW_END` = 0.85 (window closes at 85%)
- Effective window = **0.35 seconds**

Result: The window proved out at these values. No frustration reported.

---

## Approach

A single Godot 4.6 scene using colored rectangles. All nodes created programmatically in `_ready()` to avoid .tscn complexity. A timing progress bar (bottom of screen) showed the parry window visually. State machine drove the Boss attack loop automatically.

**Path chosen:** Engine
**Reason:** Feel IS the hypothesis — browser latency (50–133ms variance) would have produced false results for a timing-based parry system.

**Shortcuts taken (intentional):**
- Colored rectangles instead of sprites or animations
- No health system, no death, no menus
- No audio
- Single Boss attack type (no variety)
- No character movement
- All values hardcoded as constants

---

## Result

- Hypothesis **CONFIRMED** — player voluntarily retried without prompting
- Three distinct moments of satisfaction identified: first successful parry, finding the rhythm across multiple reps, and the visual Boss stagger (yellow flash on hardstun)
- No frustration points reported — no moments of "too tight" or "too random"
- No surprises (positive or negative)

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine (Godot 4.6) |
| Iterations to playable | 1 (ran on first attempt) |
| Prototype duration | < 1 session |
| Playtesters | 1 internal |
| Feel assessment | Satisfying at TELEGRAPH=1.0s, WINDOW=0.50–0.85 (0.35s window) |
| Hypothesis verdict | **CONFIRMED** |

---

## Recommendation: PROCEED

The parry timing window — the riskiest assumption in the entire concept — proved satisfying at first-pass defaults with no tuning required. The three-moment satisfaction arc (first hit → rhythm → stagger) maps directly to the core fantasy defined in the brainstorm: "complete mastery through understanding." No frustration signals means the window width is learnable without being trivial. This is a green light to invest in full design documentation.

---

## If Proceeding

**Core tuning values discovered:**
- `TELEGRAPH_DURATION = 1.0s` — enough time to read the glow without feeling slow
- `PARRY_WINDOW = 0.50–0.85 * telegraph` — 0.35s effective window felt learnable and satisfying
- These values should become the baseline Tuning Knobs in the Parry System GDD

**Assumptions confirmed:**
- Visual-only telegraph (color change) is sufficient feedback at prototype stage — the boss color ramp from dark red → bright orange was readable
- Instant retry loop (no death screen, no penalty) keeps the "one more try" psychology active
- A timing progress bar adds clarity without teaching bad habits

**Assumptions to investigate in GDD:**
- Single attack type tested — does rhythm satisfaction hold across 3–5 different attack patterns per Boss?
- No audio was present — audio feedback (parry clang, counter whoosh) likely amplifies the satisfaction significantly; test in vertical slice
- Color-only feedback may not be sufficient with real art (particle effects, camera shake needed)

**Emergent observations:**
- The Boss stagger (yellow flash) was a meaningful satisfaction signal on its own — worth formalizing as a "stagger window" mechanic where player can extend counter combos

**Next steps:**
1. `/design-review design/gdd/game-concept.md` — validate concept doc against prototype learnings
2. `/gate-check` — confirm readiness to advance to Systems Design
3. `/art-bible` — visual identity before writing GDDs
4. `/map-systems` — decompose concept into systems
5. `/design-system parry-system` — GDD for the parry/counter system; use TELEGRAPH=1.0s / WINDOW=0.35s as baseline Tuning Knobs

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  None broken. The core loop worked on first implementation, which is rare and a good sign the concept is solid.

- **What surprised us that didn't show up in the brainstorm?**
  The Boss stagger visual (yellow flash) emerged as an independent satisfaction moment — the brainstorm only planned for "parry success" and "counter attack." Stagger as a distinct beat is worth formalizing in the GDD.

- **What would we test differently next time?**
  Add a second attack type with different timing to test whether the rhythm satisfaction generalizes, or whether it only works for a single pattern.

---

> *Prototype code location: `prototypes/parry-counter-concept/`*
> *This code is throwaway. Never refactor into production.*
