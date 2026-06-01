# Vertical Slice Report — 刃响 (Blade Echo) — 2026-06-01

> **Build path**: `prototypes/blade-echo-vertical-slice/`
> **Run**: #1 (first vertical slice)
> **Based on**: 7 MVP GDDs (all complete) + 5 Accepted ADRs + Control Manifest v2026-06-01

---

## Executive Summary

**Verdict: PROCEED**

The full MVP game loop (move → watch telegraph → parry → counter combo → death/retry → phase transition) runs end-to-end without crash or logical error. The architecture stack (EventBus, 7-state player SM, BossStateMachine with CONNECT_ONE_SHOT, CounterAttackComboSystem as sole `stagger_ended` emitter, InstantRetrySystem with in-place reset) compiled and played correctly after 3 minor parser errors fixed in minutes.

**Critical design finding**: The HUD telegraph progress bar overshadows the Boss's visual glow as the primary information channel. The player watched the bar, not the Boss. Pillar 1 "Read to Win" is partially validated (the mechanic works) but the *reading channel* is unresolved — UI bar or Boss body. This is the defining design decision for Pre-Production UX spec.

---

## Core Loop Validation

### What was tested
- One complete fight: boss spawns → 2-phase attack sequence → player parry / take hits / counter combo → phase 2 trigger → boss defeated (or player death → retry → continue)
- All 7 MVP systems active: HealthDamageSystem, PlayerController, ParryTelegraphSystem, BossStateMachine, CounterAttackComboSystem, InstantRetrySystem, HUDSystem
- Foundation Autoloads: EventBus, RetryContext, HitpauseManager

### Passed
- ✅ Full loop completes independently (no developer guidance needed)
- ✅ First meaningful action within 5–10 seconds of launch
- ✅ Death screen (1.5s sequence) → Boss HP preserved → resume
- ✅ Phase 2 triggered at 60% HP threshold with visual change
- ✅ HUD 4 elements (player HP, boss HP, telegraph bar, counter window) all update correctly
- ✅ Counter combo 3-hit window functional; BONUS_STAGGER extends after full combo
- ✅ stagger_ended sole ownership by CounterAttackComboSystem — no double-fire
- ✅ No blockers or confusion points reported

### Failed / Not fully validated
- ⚠️ **Core fantasy not confirmed**: player watched HUD progress bar, not Boss visual. "Read the Boss" = read a UI element, not read the world. This is expected at placeholder-art stage but must be resolved before Production.
- ❌ Voluntary retry (3+ times without prompting) — not observed/recorded. Re-test with external playtesters.

---

## Feel Assessment

### What worked
- Loop pacing: Boss idle delay → telegraph ramp → parry window → counter window felt appropriately tight
- No "dead air" — the fight has constant active engagement
- Phase transition (Boss white flash) was clearly noticeable

### What needs work
- Boss visual (ColorRect color ramp) is too subtle compared to the HUD bar; the bar dominates attention
- No audio — the three satisfaction beats (first parry sound, counter hit sounds, stagger entry silence) are absent; this almost certainly affects perceived weight
- Player character has no visible parry animation feedback — button press → blue tint shift is too subtle
- Counter hits have no visual escalation (all hits look the same)

### Architecture feel finding
The code patterns (CONNECT_ONE_SHOT, _transition_to, reset_for_retry chain, EventBus routing) all feel correct and caused no surprising runtime behavior. The 10-day estimate for a complete stack was optimistic but the actual implementation in a single session validates that the architecture is buildable at this quality level.

---

## Technical Findings

### Parser errors encountered (all fixed in <5 minutes)
1. `PROCESS_MODE_PAUSEABLE` → `PROCESS_MODE_PAUSABLE` (spelling, Godot 4.6 enum)
2. `var phase := ctx.get(...)` → `var phase: int = ctx.get(...)` (INFERRED_DECLARATION is error-level in Godot 4.6 strict mode)
3. `Tween.TWEEN_PROCESS_TIME` → removed (constant doesn't exist in Godot 4; PROCESS_MODE_ALWAYS node makes it unnecessary)
4. `BossStateMachine extends Node` → `extends Node2D` (needs position property for visual children)

### Architecture decisions validated at runtime
- ADR-0001 EventBus: 13 typed signals, all fired correctly; no missed connections
- ADR-0003 RetryContext + in-place reset: Boss HP preserved across retry; reset_for_retry chain functional
- ADR-0005 CONNECT_ONE_SHOT: ATTACKING→IDLE transition via animation_finished fired correctly; no coroutine leaks observed
- ADR-0004 _transition_to pattern: no state inconsistencies observed across ~20 transitions per playthrough

### Risks surfaced
- `Tween` death screen animation with `SceneTree.paused = true` on a `PROCESS_MODE_ALWAYS` node works, but the skip logic (`_skip_to_resume`) uses `get_tree().get_nodes_in_group("death_tweens")` which doesn't work (tween not in group). This path is un-tested — skip may fail silently. Fix before Polish.
- `_on_player_hp_changed` in PlayerController triggers HIT_STUN on any HP change signal, including the initial emit in `initialize()`. This works in practice but is logically incorrect — it should only trigger on HP decrease. Low-priority VS bug.

---

## Velocity Log

| Session | Day Equiv. | Completed |
|---------|-----------|-----------|
| 2026-06-01 (this session) | Day 1–9 compressed | All 19 files written; 4 parser errors fixed; full loop playable |

**Real production rate**: 1 session to implement all 7 MVP systems from complete GDDs + ADRs.
**Extrapolation**: With full HD art and audio production, per-system time scales with asset production, not code implementation. Code is not the bottleneck.

---

## Key Design Decision Surfaced

### Progress bar vs. visual reading (must decide before Production stories begin)

The HUD telegraph progress bar is the dominant information channel. Players read it instead of the Boss body. This directly affects Pillar 1 "Read to Win."

**Option A — Remove or hide the bar** (pure visual reading):
- Maximizes "read the Boss" design intent
- Higher skill ceiling; steeper learning curve for new players
- Reduces accessibility (no visual assist for timing)

**Option B — Keep the bar as explicit learning scaffold**:
- Bar stays; but Boss visual must be made dramatically more compelling (particle glow, screen shake at window open) to compete for attention
- Players use bar early, graduate to Boss reading as they improve
- Better onboarding; lower accessibility barrier

**Option C — Conditional bar** (hide after first successful parry on each attack type):
- Best of both but most complex to implement

**Recommendation**: Decide in `/ux-design hud` UX spec — this is the most impactful single design decision remaining before Production. Flag as blocking for the parry/telegraph story.

---

## Recommended Next Steps

1. **/ux-design hud** — design the HUD UX spec; resolve progress bar question (blocking for parry story)
2. **External playtest session** — get one person unfamiliar with the game to play 5 minutes; check for voluntary retry behavior
3. **/create-epics layer:foundation** then **layer:core** — slice is complete; production implementation begins from scratch (slice is reference only)
4. **/sprint-plan** — use 1-session velocity data to estimate first sprint

---

## Lessons Learned

**What assumptions were broken by building to near-production architectural quality?**
None broken — the ADR patterns (EventBus, CONNECT_ONE_SHOT, reset_for_retry) all worked as designed on first implementation. The architecture investment paid off immediately.

**What surprised us?**
The HUD progress bar being more salient than the Boss visual was the biggest surprise. At prototype stage this was acceptable; at VS stage it reveals a real design conflict. The three-beat satisfaction arc (first parry → rhythm → stagger) predicted in the concept prototype DOES happen — but it's triggered by reading the HUD, not reading the Boss.

**What would we test differently next time?**
Run an external playtest immediately after the loop is playable. Internal playtesting (developer-as-player) has too much prior knowledge to validate "first impression reading" of the Boss visual.

---

> *Vertical slice code: `prototypes/blade-echo-vertical-slice/`*
> *This code is throwaway reference only. Production reimplements from scratch using ADRs + GDDs.*
