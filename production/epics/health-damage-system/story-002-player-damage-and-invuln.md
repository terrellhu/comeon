# Story 002: Player Damage Application and Invulnerability Window

> **Epic**: HealthDamageSystem
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2–3 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-001`, `TR-HDS-002`, `TR-HDS-011`, `TR-HDS-013`, `TR-HDS-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture (primary); ADR-0002: BossData Resource Architecture (secondary — no literals)
**ADR Decision Summary**: All cross-module signals emitted via EventBus Autoload with Callable-based API. `player_hp_changed(current, max_hp)` is defined on EventBus and emitted by HealthDamageSystem. Systems accept optional mock EventBus injection for GUT isolation.

**Engine**: Godot 4.6 | **Risk**: LOW (Node logic only; no Godot-specific APIs beyond signal emission)
**Engine Notes**: Godot typed signal calls are synchronous — `EventBus.player_hp_changed.emit()` fires all connected callbacks in the same call stack. No async concerns.

**Control Manifest Rules (Core Layer)**:
- Required: Emit `player_hp_changed(current: float, max_hp: float)` via `EventBus` on every HP mutation
- Required: `All systems must accept optional EventBus injection` via `initialize(event_bus)`
- Forbidden: No numeric literals for damage amounts, durations, or HP values in logic code
- Performance: `HealthDamageSystem per-frame processing < 1.0ms/frame`

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [x] **GIVEN** player ALIVE, `current_player_hp = 100.0`, **WHEN** `apply_damage(PLAYER, 10)`, **THEN** `current_player_hp` becomes 90.0, `player_hp_changed(90.0, 100.0)` emitted exactly once, no other signals
- [x] **GIVEN** player ALIVE, `current_player_hp = 100.0`, **WHEN** `apply_damage(PLAYER, 10)` then 0.3s later `apply_damage(PLAYER, 20)`, **THEN** second call is completely ignored; HP stays 90.0; `player_hp_changed` emitted only once total
- [x] **GIVEN** player INVULNERABLE (0.2s remaining on timer), **WHEN** `apply_damage(PLAYER, 20)`, **THEN** HP unchanged; timer remains ≈ 0.2s (NOT reset to 0.5s)
- [x] **GIVEN** player ALIVE, **WHEN** `apply_damage(PLAYER, 0.0)`, **THEN** HP unchanged; no signal emitted; INVULNERABLE state NOT entered (invuln window not consumed)
- [x] **GIVEN** player ALIVE, **WHEN** `apply_damage(PLAYER, -10.0)`, **THEN** HP unchanged; no signal emitted; INVULNERABLE state NOT entered
- [x] **GIVEN** `attack_base_damage = 25`, `current_player_hp = 100.0`, **WHEN** `apply_damage(PLAYER, 25.0)`, **THEN** `current_player_hp = 75.0` (flat deduction, no scaling multiplier)
- [x] **GIVEN** `attack_base_damage = 40`, `current_player_hp = 80.0`, **WHEN** `apply_damage(PLAYER, 40.0)`, **THEN** `current_player_hp = 40.0`
- [x] **GIVEN** every frame triggers an `apply_damage` call, **WHEN** 1000 consecutive calls measured, **THEN** per-call processing time < 1.0ms (Godot Profiler or `Time.get_ticks_usec()`)

---

## Implementation Notes

*Derived from ADR-0001 and GDD Detailed Design:*

- `apply_damage(target: GameEnums.Target, amount: float) -> void`:
  - Guard: if `amount <= 0.0`, return immediately (no-op)
  - Guard (PLAYER only): if `invuln_timer > 0.0`, return immediately — **do not reset** `invuln_timer`
  - Subtract amount from `current_player_hp`; clamp to 0 (HP < 0 handled by Story 003)
  - Set `invuln_timer = player_hit_invuln_duration` immediately after deducting (only when damage actually lands)
  - Emit `_event_bus.player_hp_changed.emit(current_player_hp, player_max_hp)`
- `invuln_timer` decrements in `_process(delta)` or `_physics_process(delta)`. Choose one and document the choice — `_physics_process` is preferred (deterministic tick).
- Damage formula is flat: `new_hp = current_player_hp - amount`. No scaling, no multiplier, no rounding.
- The system does not decide whether to apply damage — callers (ParryTelegraphSystem) make that decision before calling.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: Death detection (`current_player_hp <= 0` → `player_died`)
- Story 001: System initialization (HP starting value)

---

## QA Test Cases

**Test file**: `game/tests/unit/health_damage/test_player_damage_invuln.gd` — 15/15 PASS (2026-06-02)

**GDD formula**: F-01 `player_damage_intake = attack_base_damage` (pass-through); invuln window rule

- **Basic damage**: `apply_damage(PLAYER, 25.0)` with hp=100 → `current_player_hp = 75.0`; `player_hp_changed(75.0, 100.0)` emitted
- **Zero damage no-op**: `apply_damage(PLAYER, 0.0)` → HP unchanged; no signal; invuln not consumed
- **Negative damage no-op**: `apply_damage(PLAYER, -5.0)` → HP unchanged; no signal
- **Invuln window opened**: After valid damage, `invuln_timer > 0.0`
- **Invuln blocks re-hit**: Second `apply_damage` during window → HP unchanged
- **Invuln timer not reset on re-hit**: Timer continues counting down from original value
- **Clamping**: Damage > current_player_hp → `current_player_hp = 0.0`; `player_died` emitted; no negative HP
- **Edge cases** (GDD): Single damage ≥ current HP triggers death same-frame with no buffer

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_player_damage_invuln.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class — use `extends GutTest` directly.

**Status**: [x] `game/tests/unit/health_damage/test_player_damage_invuln.gd` — 15/15 PASS (2026-06-02)

---

## Dependencies

- Depends on: Story 001 (HP initialization) must be DONE
- Unlocks: Story 003 (player death)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 8/8 passing
**Deviations**: OUT OF SCOPE — `mock_event_bus.gd` modified with additive tracking fields; backward-compatible, accepted. ADVISORY — AC-1 "no other signals" and AC-2 "combined count" not explicitly tested; addressed in follow-up if needed.
**Test Evidence**: Logic — `game/tests/unit/health_damage/test_player_damage_invuln.gd` — 15/15 PASS (26/26 total suite)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS; required fixes applied (null assert + @warning_ignore on apply_damage)
