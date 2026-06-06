# Story 003: Full Combo + BONUS_STAGGER + stagger_ended

> **Epic**: CounterAttackComboSystem
> **Status**: Not Started
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-06-06
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/counter-attack-combo.md` — Core Rules 7–9, Formula 2
**Requirements**: `TR-CAC-005`, `TR-CAC-007`

**ADR Governing Implementation**:
- ADR-0001: `stagger_ended` is emitted ONLY by this system — no other .gd file may call `stagger_ended.emit()`
- ADR-0001: `counter_full_combo_completed(attack_type)` via EventBus

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal emission order matters — `counter_full_combo_completed` must emit before state transitions to BONUS_STAGGER.

**Control Manifest Rules (Feature Layer)**:
- `stagger_ended` is sole-emitter from CounterAttackComboSystem (ADR-0001)
- No literal 0.5 for bonus_ratio — @export

---

## Acceptance Criteria

### AC-03: Third hit triggers full combo → BONUS_STAGGER
- Given: COUNTER_WINDOW_OPEN, hit_count=2, cooldown=false
- When: `attack_input_pressed`
- Then: hit_count=3; `apply_damage(BOSS, 32.0)` called; `counter_full_combo_completed(attack_type)` emitted; state = BONUS_STAGGER

### AC-06: BONUS_STAGGER timer expires → stagger_ended + IDLE (SWEEP)
- Given: BONUS_STAGGER (SWEEP), bonus_window_timer = 1.0s
- When: Timer expires (1.0s elapses)
- Then: `stagger_ended` emitted; state = IDLE

### AC-06b: BONUS_STAGGER timer = 0.5s (LIGHT × bonus_ratio 0.5)
- Given: Full combo completed on LIGHT
- When: BONUS_STAGGER entered
- Then: bonus_window_timer = 0.5s (1.0 × 0.5); `stagger_ended` emitted after 0.5s

### AC-06c: BONUS_STAGGER timer = 0.75s (HEAVY)
- Given: Full combo completed on HEAVY
- When: BONUS_STAGGER entered
- Then: bonus_window_timer = 0.75s (1.5 × 0.5); `stagger_ended` emitted after 0.75s

### AC-07: BONUS_STAGGER ignores attack_input_pressed
- Given: State = BONUS_STAGGER
- When: `attack_input_pressed`
- Then: hit_count unchanged; `apply_damage` NOT called

### AC-08: Window expires without full combo → stagger_ended + IDLE
- Given: COUNTER_WINDOW_OPEN, hit_count=1
- When: window_timer expires (no further hits)
- Then: `stagger_ended` emitted; state = IDLE; `counter_full_combo_completed` NOT emitted; prior apply_damage calls not reversed

### AC-14: bonus_ratio clamped at 0.8
- Given: `bonus_ratio = 0.9` (over limit)
- When: System initializes
- Then: Clamped to 0.8; push_warning; SWEEP bonus = 2.0 × 0.8 = 1.6s

### AC-16: counter_window_updated state = BONUS_STAGGER per-frame during BONUS_STAGGER
- Given: State = BONUS_STAGGER
- When: `_physics_process(delta)` runs
- Then: `counter_window_updated` emitted with `state = BONUS_STAGGER`; `hit_count = 3`; `time_remaining` decreases

## Test Evidence Path

`game/tests/unit/counter_attack_combo/test_cac_bonus_stagger.gd`

## Out of Scope

- player_died/boss_defeated interruption (Story 004)
- Sole-emitter grep check (code review gate)

## Definition of Done

- [ ] All ACs pass in GUT headless (0 failing)
- [ ] `stagger_ended` emitted in exactly 2 places: window expiry + BONUS_STAGGER expiry
- [ ] `/code-review` APPROVED (verify `stagger_ended.emit()` call count in file = 2)
- [ ] `/story-done` run and Status → Complete
