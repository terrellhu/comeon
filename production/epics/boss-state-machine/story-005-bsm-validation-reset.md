# Story 005: Data Validation + reset_for_retry

> **Epic**: BossStateMachine
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirements**: `TR-BSM-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: BossData Resource Architecture (load-time validation); ADR-0003: RetryContext and Scene Reset (reset_for_retry contract)
**ADR Decision Summary**: ADR-0002: `_validate()` called at `init_battle()` time — empty attack_sequence triggers `assert(false)` or push_error + refuse init; invalid values clamped with push_warning. ADR-0003: `reset_for_retry(ctx: Dictionary)` must restore `behavior_state=IDLE`, `sequence_index=0`, clear `idle_timer` and `internal_telegraph_timer`, set `phase_index = ctx["boss_phase"]`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `push_warning()` and `push_error()` are stable Godot 4 APIs. `assert()` in non-debug builds: asserts are stripped — use `push_error` + early return for production-safe validation. `AnimationPlayer.has_animation(StringName)` stable.

**Control Manifest Rules (Feature Layer)**:
- Required: `BossStateMachine.reset_for_retry(ctx)` → behavior_state=IDLE, sequence_index=0, idle_timer=0, internal_telegraph_timer=0, phase_index=ctx["boss_phase"] — source: ADR-0003
- Required: Disconnect animation_finished callback in reset_for_retry if connected
- Forbidden: Hardcoded clamp values as literals — clamp thresholds come from GDD tuning knobs

---

## Acceptance Criteria

*From GDD `design/gdd/boss-state-machine.md`, scoped to this story:*

- [x] **AC-19** GIVEN `phase_transition_anim` 指向不存在的动画资产，WHEN 进入 PHASE_TRANSITION，THEN 跳过动画播放，直接完成 PHASE_TRANSITION 逻辑；输出 warning；战斗继续不崩溃。
- [x] **AC-20** GIVEN PhaseData.attack_sequence 为空（N=0），WHEN `init_battle(boss_data)` 加载，THEN 输出 error；系统不进入 IDLE（拒绝初始化）；Boss 无法开始战斗。
- [x] **AC-21** GIVEN PhaseData.idle_duration_after_attack = 0.0，WHEN `init_battle(boss_data)` 加载，THEN 值被 clamp 至 0.1s；输出 warning；系统正常初始化。
- [x] **AC-22** GIVEN AttackData.telegraph_duration_override = 0.005（亚帧），WHEN 攻击被选中进入 TELEGRAPHING，THEN telegraph_timer = 0.1s（clamp 后）；输出 warning。
- [x] **[ADR-0003 contract]** GIVEN BossStateMachine 处于任意非 DEFEATED 状态，WHEN `reset_for_retry(ctx)` 被调用，THEN behavior_state=IDLE；sequence_index=0；idle_timer=0.0；internal_telegraph_timer=0.0；phase_index=ctx["boss_phase"]；animation_finished callback disconnected if connected。

---

## Implementation Notes

*Derived from ADR-0002, ADR-0003:*

**Load-time validation:**
```gdscript
func init_battle(boss_data: BossData) -> void:
    assert(boss_data != null)
    _boss_data = boss_data
    for phase_data in boss_data.phases:
        assert(phase_data.attack_sequence.size() > 0,
            "BossStateMachine.init_battle: empty attack_sequence in phase %d" % phase_data.phase_index)
        if phase_data.idle_duration_after_attack <= 0.0:
            push_warning("BossStateMachine: idle_duration_after_attack=0 in phase %d — clamping to 0.1s" % phase_data.phase_index)
            phase_data.idle_duration_after_attack = 0.1
    # ...
```

**reset_for_retry:**
```gdscript
func reset_for_retry(ctx: Dictionary) -> void:
    assert(ctx.has("boss_phase"), "reset_for_retry: ctx must contain 'boss_phase'")
    # Disconnect any pending animation callback
    if _anim_player != null and _anim_player.animation_finished.is_connected(_on_attack_animation_done):
        _anim_player.animation_finished.disconnect(_on_attack_animation_done)
    if _anim_player != null and _anim_player.animation_finished.is_connected(_on_phase_transition_done):
        _anim_player.animation_finished.disconnect(_on_phase_transition_done)
    behavior_state = BehaviorState.IDLE  # direct write — reset bypasses _transition_to
    sequence_index = 0
    idle_timer = 0.0
    internal_telegraph_timer = 0.0
    _pending_phase_transition = false
    _pending_to_phase = 0
    var phase_idx: int = ctx.get("boss_phase", 0) as int
    _current_phase_data = _boss_data.phases[phase_idx]
```

**Sub-frame telegraph clamp:**
```gdscript
func _get_effective_telegraph_duration(attack: AttackData) -> float:
    var duration: float = ...  # as before
    if duration < 0.016:  # < 1 frame at 60fps
        push_warning("BossStateMachine: telegraph_duration_override sub-frame — clamping to 0.1s")
        return 0.1
    return duration
```

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 004: phase_transition_anim missing at runtime during PHASE_TRANSITION (AC-19 runtime behavior)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-06-04.md` S002-F01 test specs.*

- **AC-20**: Empty attack_sequence → error + refuse init
  - Given: BossData with PhaseData.attack_sequence=[] (empty)
  - When: `init_battle(boss_data)` called
  - Then: push_error called; system not in IDLE (init refused); `attack_telegraphed` never emitted

- **AC-21**: idle_duration=0.0 → clamped to 0.1s + warning
  - Given: BossData with idle_duration_after_attack=0.0
  - When: `init_battle(boss_data)` called
  - Then: push_warning called; idle_duration_after_attack=0.1 after init; system initializes normally

- **AC-22**: telegraph_duration_override=0.005 → clamped to 0.1s + warning
  - Given: AttackData(telegraph_duration_override=0.005)
  - When: attack selected, `_get_effective_telegraph_duration` called
  - Then: returns 0.1; push_warning called

- **[ADR-0003 reset_for_retry]**: Reset from ATTACKING state
  - Given: behavior_state=ATTACKING; sequence_index=2; idle_timer=0.3; ctx={"boss_phase": 1, "boss_hp": 750.0}
  - When: `reset_for_retry(ctx)` called
  - Then: behavior_state=IDLE; sequence_index=0; idle_timer=0.0; internal_telegraph_timer=0.0; _current_phase_data=phase[1]
  - Edge cases: animation_finished callback disconnected; reset from PHASE_TRANSITION also works

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/boss_state_machine/test_bsm_validation_reset.gd` — must exist and pass

**Status**: [x] PASS — `game/tests/unit/boss_state_machine/test_bsm_validation_reset.gd` — 18/18 PASS (BSM total 70/70)

---

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 5/5 passing
**Deviations**: ADVISORY — AC-20 uses push_error + early return (not assert), correct per Engine Notes (assert stripped in Release). AC-20 "attack_telegraphed never emitted" not directly asserted in tests (indirect via behavior_state check).
**Test Evidence**: Logic — `game/tests/unit/boss_state_machine/test_bsm_validation_reset.gd` (18 tests, 18/18 PASS)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS; test naming fix applied (is_clamped → is_not_clamped)

---

## Dependencies

- Depends on: Story 004 (phase transition logic must exist for AC-19 runtime path)
- Unlocks: All subsequent Feature systems (InstantRetrySystem depends on BossStateMachine.reset_for_retry)
