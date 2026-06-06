# Story 002: STAGGERED + Sequence Index Formula

> **Epic**: BossStateMachine
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-05

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirements**: `TR-BSM-004`, `TR-BSM-005`, `TR-BSM-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Player State Machine Architecture (primary); ADR-0001: Signal Routing (secondary)
**ADR Decision Summary**: ADR-0004: STAGGERED entered via `parry_succeeded` signal subscription; `stagger_ended` from CounterAttackComboSystem drives exit. Sequence index formula `(current + 1) mod N` applied at both ATTACKING exit and STAGGERED exit. ADR-0001: signal subscriptions via EventBus; `parry_succeeded(type)` and `stagger_ended` routed via EventBus.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal subscriptions are standard Godot 4 Callable API. No post-cutoff APIs used.

**Control Manifest Rules (Feature Layer)**:
- Required: `behavior_state` reads only via `_transition_to` pattern
- Required: No hardcoded stagger duration literals — stagger managed entirely by CounterAttackComboSystem; BossStateMachine only waits for `stagger_ended`
- Forbidden: BossStateMachine emitting `stagger_ended` — sole ownership by CounterAttackComboSystem (ADR-0001)

---

## Acceptance Criteria

*From GDD `design/gdd/boss-state-machine.md`, scoped to this story:*

- [x] **AC-02** GIVEN 系统 TELEGRAPHING，WHEN 收到 `parry_succeeded(attack_type)`，THEN 进入 STAGGERED；之后 N 秒内不再发出 `attack_telegraphed`（timer 已取消的间接验证）。
- [x] **AC-05** GIVEN 系统 STAGGERED，WHEN 收到 `stagger_ended`，THEN `sequence_index = (current_index + 1) mod N`；系统进入 IDLE 状态。
- [x] **AC-07** GIVEN 序列长度 N=3，sequence_index=2（末尾），WHEN ATTACKING 动画结束，THEN sequence_index 推进后 = 0（循环回头）。
- [x] **AC-08** GIVEN 序列长度 N=3，sequence_index=2（末尾），WHEN 收到 `stagger_ended`，THEN sequence_index 推进后 = 0（STAGGERED 退出也触发循环）。
- [x] **AC-13** GIVEN 系统 ATTACKING，WHEN 收到 `parry_failed(attack_type)`，THEN 状态保持 ATTACKING；不发出任何状态转换信号。

---

## Implementation Notes

*Derived from ADR-0004 and ADR-0001:*

**STAGGERED entry:**
```gdscript
func _on_parry_succeeded(_attack_type: GameEnums.AttackType) -> void:
    if behavior_state == BehaviorState.TELEGRAPHING:
        _transition_to(BehaviorState.STAGGERED)
    # If not TELEGRAPHING (e.g. already ATTACKING): ignore
```

**STAGGERED exit via stagger_ended:**
```gdscript
func _on_stagger_ended() -> void:
    if behavior_state != BehaviorState.STAGGERED:
        return
    sequence_index = (sequence_index + 1) % _current_phase_data.attack_sequence.size()
    _transition_to(BehaviorState.IDLE)
```

**Signal subscriptions setup (new `_ready()`):**
```gdscript
func _ready() -> void:
    # initialize() must be called before add_child() so _event_bus is set by the time
    # _ready() runs. The test harness (Story 001 pattern) already guarantees this order.
    @warning_ignore("unsafe_property_access")
    _event_bus.parry_succeeded.connect(_on_parry_succeeded)
    @warning_ignore("unsafe_property_access")
    _event_bus.stagger_ended.connect(_on_stagger_ended)
    @warning_ignore("unsafe_property_access")
    _event_bus.parry_failed.connect(_on_parry_failed)
```

**Note — AC-11 / T_default lookup (out of scope):**
The effective telegraph duration formula for `override == 0.0` requires
`BossData.get_default_telegraph_duration()`. Story 001 left a named fallback
constant (`_FALLBACK_TELEGRAPH_DURATION = 0.1`) and a `push_error` until
the lookup is implemented. That fallback remains in place for Story 002.
Story 003 owns TR-BSM-003 and will add the `default_telegraph_durations`
dictionary to BossData and implement the real lookup.

**parry_failed: state preserved**
```gdscript
func _on_parry_failed(_attack_type: GameEnums.AttackType) -> void:
    pass  # parry_failed is informational only — BossStateMachine does not change state
```

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001: IDLE/TELEGRAPHING/ATTACKING main path
- Story 003: DEFEATED terminal state + boss_defeated; **AC-11** (T_default[type] from BossData — TR-BSM-003 is Story 003's deliverable)
- Story 004: boss_phase_changed 4-path handling
- Story 005: data validation + reset_for_retry

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-06-04.md` S002-F01 test specs.*

- **AC-02**: parry_succeeded → STAGGERED; telegraph cancelled
  - Given: behavior_state=TELEGRAPHING; internal_telegraph_timer=0.5s remaining
  - When: `_on_parry_succeeded(HEAVY)` called
  - Then: behavior_state=STAGGERED; internal_telegraph_timer=0.0 (cancelled); no `attack_telegraphed` emitted in next 2s
  - Edge cases: parry_succeeded received when NOT in TELEGRAPHING → state unchanged

- **AC-05**: stagger_ended → sequence_index++ → IDLE
  - Given: behavior_state=STAGGERED; sequence_index=1; N=3
  - When: `_on_stagger_ended()` called
  - Then: sequence_index=2; behavior_state=IDLE

- **AC-07**: sequence wrap-around via ATTACKING exit (N=3, index=2)
  - Given: behavior_state=ATTACKING; sequence_index=2; N=3
  - When: animation_finished fires
  - Then: sequence_index=0 (wraps)

- **AC-08**: sequence wrap-around via STAGGERED exit (N=3, index=2)
  - Given: behavior_state=STAGGERED; sequence_index=2; N=3
  - When: `_on_stagger_ended()` called
  - Then: sequence_index=0 (wraps)

- **AC-13**: parry_failed during ATTACKING: state unchanged
  - Given: behavior_state=ATTACKING
  - When: `_on_parry_failed(LIGHT)` called
  - Then: behavior_state still ATTACKING; no signals emitted

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/boss_state_machine/test_bsm_stagger_sequence.gd` — must exist and pass

**Status**: [x] Complete — `game/tests/unit/boss_state_machine/test_bsm_stagger_sequence.gd` — 11/11 passing (2026-06-05)

---

## Dependencies

- Depends on: Story 001 (IDLE/TELEGRAPHING/ATTACKING skeleton must exist) ✅ Complete
- Pre-condition: Add `test_exit_attacking_clears_pending_anim_fallback` test ✅ Included in this story's test file
- Unlocks: Story 003 (DEFEATED interrupts STAGGERED)

---

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 5/5 passing
**Deviations**: None
**Test Evidence**: Logic story — `game/tests/unit/boss_state_machine/test_bsm_stagger_sequence.gd` — 11/11 passing (9 AC tests + 2 EventBus wiring tests)
**Code Review**: Complete — CHANGES REQUIRED → fixes applied → APPROVED (2026-06-05)
**Notable**: Guard style fixed (positive→negative early-return); EventBus subscription wiring tested end-to-end; tech-debt `test_exit_attacking_clears_pending_anim_fallback` cleared with precondition assertion
