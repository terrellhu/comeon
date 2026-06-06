# Story 001: BSM Skeleton + IDLE/TELEGRAPHING/ATTACKING Main Path

> **Epic**: BossStateMachine
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (2–3 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-05
> **Started**: 2026-06-04

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirements**: `TR-BSM-001`, `TR-BSM-006`, `TR-BSM-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Player State Machine Architecture (primary); ADR-0005: Animation-to-Code Boundary (ATTACKING→IDLE); ADR-0001: Signal Routing (secondary)
**ADR Decision Summary**: ADR-0004: all state machines use `enum BehaviorState` + `_transition_to(state)` pattern; no direct state field writes outside `_transition_to`. ADR-0005: ATTACKING→IDLE transition driven by `AnimationPlayer.animation_finished` connected with `CONNECT_ONE_SHOT` — never `await`, never a Timer node. ADR-0001: attack_telegraphed emitted via EventBus before telegraph_timer starts.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `AnimationPlayer.animation_finished` signal confirmed stable in Godot 4.6. `playback_active` deprecated in 4.3 — do not use. `CONNECT_ONE_SHOT` available since 4.0. Disconnect must be explicit in `_exit_state(ATTACKING)`.

**Control Manifest Rules (Feature Layer)**:
- Required: `AnimationPlayer.animation_finished.connect(_on_attack_animation_done, CONNECT_ONE_SHOT)` in `_enter_state(ATTACKING)`
- Required: `_exit_state(ATTACKING)` must disconnect the callback if still connected
- Required: `_on_attack_animation_done` must guard `if behavior_state != BehaviorState.ATTACKING: return` as first line
- Required: BossStateMachine contains no AttackType default duration literals (0.8, 1.2, 1.5s)
- Forbidden: `await anim_player.animation_finished`
- Forbidden: Separate Timer node for ATTACKING duration
- Forbidden: `PROCESS_MODE_ALWAYS` on BossStateMachine (use default PAUSEABLE)

---

## Acceptance Criteria

*From GDD `design/gdd/boss-state-machine.md`, scoped to this story:*

- [x] **AC-01** GIVEN 系统处于 IDLE 状态且 BossData 已注入（PhaseData[0].attack_sequence 非空），WHEN idle_timer 耗尽，THEN 先发出 `attack_telegraphed(sequence[0].attack_type, sequence[0].damage)` 信号，然后 telegraph_timer 启动；系统进入 TELEGRAPHING 状态。
- [x] **AC-03** GIVEN 系统 TELEGRAPHING 且无格挡输入，WHEN telegraph_timer 耗尽，THEN 进入 ATTACKING 状态。
- [x] **AC-04** GIVEN 系统 ATTACKING，WHEN `AnimationPlayer.animation_finished` 触发，THEN `sequence_index = (current_index + 1) mod N`；系统进入 IDLE 状态。
- [x] **AC-09** GIVEN 系统初始化，WHEN 进入 IDLE 状态，THEN sequence_index = 0（初始状态显式验证）。
- [x] **AC-12** GIVEN 系统 IDLE，idle_timer 耗尽，WHEN 攻击被选中，THEN 先发出 `attack_telegraphed` 信号，然后 telegraph_timer 启动（信号发出早于计时器启动，防止格挡系统错过信号）。
- [x] **[Code Review AC]** BossStateMachine .gd 文件无字面量 `0.8`、`1.2`、`1.5` — 全部时长值通过 BossData Resource 注入。

---

## Implementation Notes

*Derived from ADR-0004, ADR-0005, and control-manifest.md:*

**State machine structure:**
```gdscript
enum BehaviorState { IDLE, TELEGRAPHING, ATTACKING, STAGGERED, PHASE_TRANSITION, DEFEATED }
var behavior_state: BehaviorState = BehaviorState.IDLE
var sequence_index: int = 0
var idle_timer: float = 0.0
var internal_telegraph_timer: float = 0.0

func _transition_to(new_state: BehaviorState) -> void:
    _exit_state(behavior_state)
    behavior_state = new_state
    _enter_state(new_state)
```

**ATTACKING→IDLE with animation_finished:**
```gdscript
func _enter_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.ATTACKING:
            _anim_player.play(&"attack")
            _anim_player.animation_finished.connect(_on_attack_animation_done, CONNECT_ONE_SHOT)

func _exit_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.ATTACKING:
            if _anim_player.animation_finished.is_connected(_on_attack_animation_done):
                _anim_player.animation_finished.disconnect(_on_attack_animation_done)

func _on_attack_animation_done(_anim_name: StringName) -> void:
    if behavior_state != BehaviorState.ATTACKING:
        return  # state guard — handles disconnect-delay edge case
    sequence_index = (sequence_index + 1) % _current_phase_data.attack_sequence.size()
    _transition_to(BehaviorState.IDLE)
```

**signal-before-timer order (AC-12):**
```gdscript
# In _enter_state(TELEGRAPHING):
@warning_ignore("unsafe_property_access")
_event_bus.attack_telegraphed.emit(current_attack.attack_type, current_attack.damage)  # FIRST
internal_telegraph_timer = _get_effective_telegraph_duration(current_attack)            # THEN timer
```

**Performance**: BossStateMachine `_physics_process` is O(1) timer decrement only.
No per-frame signal emission in this story (`attack_telegraphed` is event-triggered, not per-frame).
Performance impact negligible — no profiler verification required for this story.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: STAGGERED state + sequence index wrap-around formula tests
- Story 003: DEFEATED terminal state + boss_defeated signal handling
- Story 004: boss_phase_changed handling across 4 source states
- Story 005: data validation (empty sequence, clamping) + reset_for_retry

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-06-04.md` S002-F01 test specs.*

- **AC-01**: IDLE → TELEGRAPHING on idle_timer expiry
  - Given: BossStateMachine initialized with valid BossData; behavior_state=IDLE; idle_timer=0 (expired)
  - When: `_physics_process(delta)` processes the idle_timer expiry
  - Then: `attack_telegraphed.emit(LIGHT, 10.0)` called exactly once; behavior_state=TELEGRAPHING; internal_telegraph_timer > 0
  - Edge cases: sequence[0] is LIGHT attack; verify signal payload matches AttackData values

- **AC-03**: TELEGRAPHING → ATTACKING on telegraph_timer expiry
  - Given: behavior_state=TELEGRAPHING; internal_telegraph_timer=0 (expired); no parry_succeeded received
  - When: `_physics_process(delta)` processes expiry
  - Then: behavior_state=ATTACKING; AnimationPlayer.play() called with attack animation name

- **AC-04**: ATTACKING → IDLE on animation_finished (sequence advance)
  - Given: behavior_state=ATTACKING; AnimationPlayer playing; sequence_index=0; N=2
  - When: `_on_attack_animation_done` fires
  - Then: sequence_index=1; behavior_state=IDLE; idle_timer reset to idle_duration_after_attack

- **AC-09**: Initialization sequence_index=0
  - Given: BossStateMachine freshly initialized with BossData
  - When: `init_battle(boss_data)` called
  - Then: sequence_index=0; behavior_state=IDLE

- **AC-12**: Signal emitted BEFORE timer starts
  - Given: behavior_state=IDLE; idle_timer about to expire
  - When: state transitions to TELEGRAPHING
  - Then: `attack_telegraphed` emission timestamp < `internal_telegraph_timer` assignment timestamp (same frame; verify via call order in _enter_state)

- **[Code Review]**: grep `boss_state_machine.gd` for `0.8`, `1.2`, `1.5` → zero matches

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/boss_state_machine/test_bsm_skeleton.gd` — must exist and pass

**Status**: [x] Complete — `game/tests/unit/boss_state_machine/test_bsm_skeleton.gd` — 16/16 passing (2026-06-05)

---

## Dependencies

- Depends on: HealthDamageSystem (Done — Sprint 001), BossData Resource (Done — Sprint 001), EventBus (Done — Sprint 001)
- Unlocks: Story 002 (STAGGERED needs TELEGRAPHING path from this story)

---

## Completion Notes

**Completed**: 2026-06-05
**Criteria**: 6/6 passing
**Deviations**: 3 advisory (logged to tech-debt-register.md)
  1. `_boss_data` stored but unused in Story 001 — doc comment updated to clarify pre-storage for Story 004/005. No code impact.
  2. `@export var _anim_player` underscore prefix convention inconsistency with Godot 4 @export idiom.
  3. Missing test for `_pending_anim_fallback` cleanup in `_exit_state(ATTACKING)` — scaffold provided, must add before Story 002.
**Test Evidence**: Logic story — `game/tests/unit/boss_state_machine/test_bsm_skeleton.gd` — 16/16 passing
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (2026-06-05)
