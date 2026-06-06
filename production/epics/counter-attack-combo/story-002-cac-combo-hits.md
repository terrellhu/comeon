# Story 002: Combo Hit Processing — apply_damage + Cooldown

> **Epic**: CounterAttackComboSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/counter-attack-combo.md` — Core Rules 5–6, Formulas 1 + 3
**Requirements**: `TR-CAC-003`, `TR-CAC-004`, `TR-CAC-009`

**ADR Governing Implementation**:
- ADR-0001: `apply_damage(BOSS, amount)` called on HealthDamageSystem reference (injected)
- GAP-02 RESOLVED: `counter_base_damage` and `multiplier[n]` injected via @export (not AttackData; stored on system as @export per control-manifest default)

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Feature Layer)**:
- No literals 0.8, 1.1, 1.6 (multipliers) or 20.0 (base_damage) — all @export
- hit_animation_duration must be validated at load (clamp > 0.307s to 0.30s)

---

## Acceptance Criteria

### AC-02: First hit → apply_damage(BOSS, 16.0) and cooldown activated
- Given: COUNTER_WINDOW_OPEN, hit_count=0, cooldown=false
- When: `attack_input_pressed`
- Then: `hit_count = 1`; `apply_damage(BOSS, 16.0)` called (20×0.8); `hit_cooldown_active = true`

### AC-02b: Second hit → apply_damage(BOSS, 22.0)
- Given: COUNTER_WINDOW_OPEN, hit_count=1, cooldown=false
- When: `attack_input_pressed`
- Then: `hit_count = 2`; `apply_damage(BOSS, 22.0)` called (20×1.1); `hit_cooldown_active = true`

### AC-04: Cooldown blocks rapid input
- Given: COUNTER_WINDOW_OPEN, `hit_cooldown_active = true`
- When: `attack_input_pressed`
- Then: hit_count unchanged; `apply_damage` NOT called

### AC-05: Cooldown expires after hit_animation_duration
- Given: `hit_cooldown_active = true`
- When: `hit_animation_duration` (0.25s default) elapses via delta
- Then: `hit_cooldown_active = false`; next `attack_input_pressed` is processed normally

### AC-12: Multipliers read from config (not hardcoded)
- Given: `multiplier[1] = 1.0`, `multiplier[2] = 1.5`, `multiplier[3] = 2.0` injected (non-default values)
- When: Three consecutive hits (cooldown bypassed via direct state)
- Then: `apply_damage` called with 20.0, 30.0, 40.0 respectively; not default 16/22/32

### AC-13: hit_animation_duration clamped on load
- Given: `hit_animation_duration` configured = 0.35s
- When: System initializes
- Then: Value clamped to 0.30s; push_warning called

## Test Evidence Path

`game/tests/unit/counter_attack_combo/test_cac_combo_hits.gd`

## Out of Scope

- Third hit triggering full combo / BONUS_STAGGER (Story 003)
- BONUS_STAGGER behavior (Story 003)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] Hit damage formula implemented with @export multipliers
- [ ] `/code-review` APPROVED
- [ ] `/story-done` run and Status → Complete
