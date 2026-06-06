# Story 004: Boss Phase Transitions (4 Source State Paths)

> **Epic**: BossStateMachine
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: L (3–4 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-06
> **Completed**: 2026-06-06

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirements**: `TR-BSM-007`, `TR-BSM-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: State Machine Architecture (primary); ADR-0001: Signal Routing (boss_phase_changed via EventBus)
**ADR Decision Summary**: ADR-0004: `_transition_to(PHASE_TRANSITION)` with PhaseData update and `sequence_index = 0` upon completion. PHASE_TRANSITION completion timing differs by source state: immediate from IDLE, deferred from TELEGRAPHING/ATTACKING/STAGGERED. Second `boss_phase_changed` during PHASE_TRANSITION discarded (last-wins for to_phase value). ADR-0001: `boss_phase_changed(from, to)` received via EventBus subscription.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: PHASE_TRANSITION requires AnimationPlayer for the phase-change visual. If `phase_transition_anim` string not found in AnimationPlayer, graceful skip (no crash). `AnimationPlayer.has_animation(StringName)` available since Godot 4.0.

**Control Manifest Rules (Feature Layer)**:
- Required: PHASE_TRANSITION completion → PhaseData updated; sequence_index=0; enter IDLE
- Required: On `boss_phase_changed` during TELEGRAPHING/ATTACKING/STAGGERED → "pend" the transition until current action resolves, then skip idle
- Forbidden: Advancing sequence_index during PHASE_TRANSITION (must reset to 0)

---

## Acceptance Criteria

*From GDD `design/gdd/boss-state-machine.md`, scoped to this story:*

- [x] **AC-14** GIVEN 系统 IDLE，WHEN 收到 `boss_phase_changed(1, 2)`，THEN 立即进入 PHASE_TRANSITION；动画完成后 PhaseData = phase[2]、sequence_index=0、进入 IDLE。
- [x] **AC-15** GIVEN 系统 TELEGRAPHING，WHEN 收到 `boss_phase_changed(1, 2)`，THEN telegraph 继续计时；telegraph 耗尽后（或被格挡后 STAGGERED 完成后），立即进入 PHASE_TRANSITION（跳过 idle 计时）；动画完成后 PhaseData=phase[2]、sequence_index=0。
- [x] **AC-16** GIVEN 系统 ATTACKING（动画播放中），WHEN 收到 `boss_phase_changed(1, 2)`，THEN 等待攻击动画完成（sequence_index++ 正常执行）后立即进入 PHASE_TRANSITION（跳过 idle 计时）；动画完成后 PhaseData=phase[2]、sequence_index=0。
- [x] **AC-17** GIVEN 系统 STAGGERED，WHEN 收到 `boss_phase_changed(1, 2)`，THEN 等待 `stagger_ended`（sequence_index++ 正常执行）后立即进入 PHASE_TRANSITION（跳过 idle 计时）；动画完成后 PhaseData=phase[2]、sequence_index=0。
- [x] **AC-18** GIVEN 系统 PHASE_TRANSITION（动画播放中），WHEN 再次收到 `boss_phase_changed(2, 3)`，THEN 第二个信号被丢弃并输出 warning；当前过渡动画完整播放后，进入 phase[3]（最新 to_phase）；sequence_index=0。
- [x] **[Edge Case]** GIVEN `phase_transition_anim` 字符串不对应任何动画资产，WHEN 进入 PHASE_TRANSITION，THEN 跳过动画播放（AnimationPlayer.has_animation 检查），直接完成 PHASE_TRANSITION 逻辑；输出 warning；不崩溃（见 AC-19 in Story 005 for data validation）。

---

## Implementation Notes

*Derived from ADR-0004:*

**Pending phase transition pattern:**
```gdscript
var _pending_phase_transition: bool = false
var _pending_to_phase: int = 0

func _on_boss_phase_changed(_from_phase: int, to_phase: int) -> void:
    if behavior_state == BehaviorState.DEFEATED:
        return
    if behavior_state == BehaviorState.PHASE_TRANSITION:
        # AC-18: discard second signal, update target only
        push_warning("BossStateMachine: boss_phase_changed received during PHASE_TRANSITION — discarding, will use latest to_phase=%d" % to_phase)
        _pending_to_phase = to_phase  # "last wins"
        return
    if behavior_state == BehaviorState.IDLE:
        _pending_to_phase = to_phase
        _transition_to(BehaviorState.PHASE_TRANSITION)
    else:
        # TELEGRAPHING, ATTACKING, STAGGERED: pend
        _pending_phase_transition = true
        _pending_to_phase = to_phase

# After ATTACKING→IDLE (in _on_attack_animation_done):
    sequence_index = (sequence_index + 1) % ...
    if _pending_phase_transition:
        _pending_phase_transition = false
        _transition_to(BehaviorState.PHASE_TRANSITION)  # skip IDLE
    else:
        _transition_to(BehaviorState.IDLE)

# Similar pattern in _on_stagger_ended
```

**New private state vars (declare with other private state):**
```gdscript
var _pending_phase_transition: bool = false
var _pending_to_phase: int = 0
```

**`_ready()` — add as 5th EventBus subscription (after boss_defeated):**
```gdscript
    @warning_ignore("unsafe_property_access")
    _event_bus.boss_phase_changed.connect(_on_boss_phase_changed)
```

**`init_battle()` — add to reset sequence (alongside `_pending_anim_fallback`):**
```gdscript
    _pending_phase_transition = false
    _pending_to_phase = 0
```
These MUST be reset — a stale `_pending_phase_transition = true` from a previous
battle would trigger an unexpected PHASE_TRANSITION on the next `_on_attack_animation_done`.

**PHASE_TRANSITION completion (null-safe `_anim_player` check):**
```gdscript
func _enter_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.PHASE_TRANSITION:
            var anim_name: StringName = _boss_data.phases[_pending_to_phase].phase_transition_anim
            # _anim_player may be null in headless tests — check before access (ADR-0005 pattern).
            if _anim_player != null and not anim_name.is_empty() and _anim_player.has_animation(anim_name):
                _anim_player.play(anim_name)
                _anim_player.animation_finished.connect(_on_phase_transition_done, CONNECT_ONE_SHOT)
            else:
                if not anim_name.is_empty():
                    push_warning("BossStateMachine: phase_transition_anim '%s' not found — graceful skip" % anim_name)
                _complete_phase_transition()  # immediate if no animation or _anim_player is null

func _on_phase_transition_done(_name: StringName) -> void:
    _complete_phase_transition()

func _complete_phase_transition() -> void:
    _current_phase_data = _boss_data.phases[_pending_to_phase]
    sequence_index = 0
    _transition_to(BehaviorState.IDLE)
```

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: `boss_defeated` TERMINAL state
- Story 005: Data validation for phase_transition_anim (AC-19)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-06-04.md` S002-F01 test specs.*

- **AC-14**: IDLE → PHASE_TRANSITION immediately on boss_phase_changed
  - Given: behavior_state=IDLE; BossData has 2 phases
  - When: `_on_boss_phase_changed(1, 2)` called
  - Then: behavior_state=PHASE_TRANSITION; _pending_to_phase=2
  - After animation completes: PhaseData updated to phase[2]; sequence_index=0; behavior_state=IDLE

- **AC-15**: TELEGRAPHING → complete telegraph → PHASE_TRANSITION (skip idle)
  - Given: behavior_state=TELEGRAPHING; _pending_phase_transition=false
  - When: `_on_boss_phase_changed(1, 2)` called (sets _pending_phase_transition=true)
  - Then: behavior_state still TELEGRAPHING
  - When: telegraph expires (ATTACKING transition), or parry_succeeded (STAGGERED)
  - Then: After resolution, behavior_state=PHASE_TRANSITION (not IDLE)

- **AC-16**: ATTACKING → complete animation → PHASE_TRANSITION (skip idle)
  - Given: behavior_state=ATTACKING; _pending_phase_transition=false
  - When: `_on_boss_phase_changed(1, 2)` called
  - Then: behavior_state still ATTACKING
  - When: animation_finished fires
  - Then: sequence_index incremented; behavior_state=PHASE_TRANSITION (not IDLE)

- **AC-17**: STAGGERED → stagger_ended → PHASE_TRANSITION (skip idle)
  - Given: behavior_state=STAGGERED; _pending_phase_transition=false
  - When: `_on_boss_phase_changed(1, 2)` called
  - Then: behavior_state still STAGGERED
  - When: `_on_stagger_ended()` called
  - Then: sequence_index incremented; behavior_state=PHASE_TRANSITION (not IDLE)

- **AC-18**: Second boss_phase_changed during PHASE_TRANSITION: warning + last-wins
  - Given: behavior_state=PHASE_TRANSITION; _pending_to_phase=2
  - When: `_on_boss_phase_changed(2, 3)` called
  - Then: warning logged; _pending_to_phase=3 (updated to latest); behavior_state still PHASE_TRANSITION
  - When: animation completes
  - Then: PhaseData = phase[3]; sequence_index=0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/boss_state_machine/test_bsm_phase_transition.gd` — must exist and pass

**Status**: [x] PASS — `game/tests/unit/boss_state_machine/test_bsm_phase_transition.gd` — 13/13 PASS

---

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 6/6 passing (AC-14, AC-15, AC-16, AC-17, AC-18, Edge Case — all covered)
**Deviations**: None
**Test Evidence**: Logic — `game/tests/unit/boss_state_machine/test_bsm_phase_transition.gd` (13 tests, 13/13 PASS; BSM total 51/51)
**Code Review**: Complete — /code-review passed with suggestions handled

---

## Dependencies

- Depends on: Story 003 (DEFEATED state needed to verify boss_defeated priority in phase transition tests)
- Unlocks: Story 005 (validation + reset completes the epic)
