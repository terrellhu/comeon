# Story 004: Healing Application and Over-Heal Guard

> **Epic**: HealthDamageSystem
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture (primary)
**ADR Decision Summary**: `player_hp_changed(current, max_hp)` is emitted via EventBus on every HP mutation including healing. No other signal is required for healing — it does not affect Boss state or trigger death.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: None — pure arithmetic and signal emission.

**Control Manifest Rules (Core Layer)**:
- Required: Emit `player_hp_changed` via EventBus after healing resolves
- Required: HP invariant — `current_player_hp` must always be in `[0, player_max_hp]`; HP > max must never be stored
- Forbidden: No hardcoded max HP value in healing logic

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [ ] **GIVEN** player ALIVE, `current_player_hp = 80.0`, `player_max_hp = 100.0`, **WHEN** `apply_healing(PLAYER, 30)`, **THEN** `current_player_hp = 100.0` (NOT 110.0); `player_hp_changed(100.0, 100.0)` emitted
- [ ] **GIVEN** `current_player_hp = 80.0`, **WHEN** `apply_healing(PLAYER, 40)` (would exceed max), **THEN** `current_player_hp = 100.0` — value 120.0 is never written to the HP field
- [ ] **GIVEN** `current_player_hp = 100.0` (full HP), **WHEN** `apply_healing(PLAYER, 20)`, **THEN** `current_player_hp` stays 100.0; `player_hp_changed(100.0, 100.0)` still emitted (heal at full is not an error)

---

## Implementation Notes

*Derived from ADR-0001 and GDD Detailed Design:*

- `apply_healing(target: GameEnums.Target, amount: float) -> void`:
  ```gdscript
  current_player_hp = minf(player_max_hp, current_player_hp + amount)
  _event_bus.player_hp_changed.emit(current_player_hp, player_max_hp)
  ```
- Use `minf` for the clamp — same pattern as `maxf` in damage application. Single expression, no conditional.
- Healing never triggers death or invuln state — no additional guards needed.
- The Heal system (vertical slice feature) calls this method. HealthDamageSystem does not own the resource cost — it only receives the healed amount.
- `apply_healing(BOSS, amount)` is not used in MVP (Bosses do not heal). Implement PLAYER branch only; BOSS branch can be a no-op or debug assertion.
- **Performance**: Pure arithmetic + 1 signal emit — O(1), no allocation. Well within TR-HDS-015 budget (< 1.0ms/frame).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Heal System resource cost logic (vertical slice, not MVP)
- Any visual/audio feedback for healing (not HealthDamageSystem's responsibility)

---

## QA Test Cases

*QL-STORY-READY skipped — Lean mode. Run `/qa-plan health-damage-system` to generate full test specifications.*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_player_healing.gd` — must exist and pass

> **GUT naming rule**: file must start with `test_`. Do NOT use `class_name` on the test class.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HP initialization) must be DONE
- Unlocks: None directly (Healing System story in vertical-slice epic will depend on this)
