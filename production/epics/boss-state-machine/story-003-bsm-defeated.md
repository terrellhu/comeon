# Story 003: DEFEATED Terminal State + BossData Injection

> **Epic**: BossStateMachine
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M (2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-06

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirements**: `TR-BSM-002`, `TR-BSM-003`, `TR-BSM-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: State Machine Architecture (primary); ADR-0002: BossData Resource (BossData drives all data); ADR-0001: Signal Routing (boss_defeated via EventBus)
**ADR Decision Summary**: ADR-0004: DEFEATED is a TERMINAL state — once entered, no exit condition. `boss_defeated` received in any state triggers immediate `_transition_to(DEFEATED)`, pre-empting any in-progress state. ADR-0002: BossData Resource subclass; BossStateMachine receives BossData at init_battle(); all timing values looked up from BossData.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `AnimationPlayer.stop()` does NOT emit `animation_finished` — boss_defeated must disconnect the one-shot callback explicitly. Confirmed ADR-0005 contract.

**Control Manifest Rules (Feature Layer)**:
- Required: `boss_defeated` → immediate DEFEATED from any state; cancels all timers
- Required: DEFEATED has no exit condition (no `_transition_to` out of DEFEATED)
- Forbidden: BossStateMachine emitting `boss_defeated` — HealthDamageSystem is the sole emitter
- Forbidden: AttackType default duration literals in .gd

---

## Acceptance Criteria

*From GDD `design/gdd/boss-state-machine.md`, scoped to this story:*

- [x] **AC-06** GIVEN 系统任意状态，WHEN 收到 `boss_defeated`，THEN 立即进入 DEFEATED；之后 3 秒内不发出 `attack_telegraphed`（间接验证所有计时器已停）。
- [x] **AC-10** GIVEN AttackData.telegraph_duration_override = 0.6（attack_type=LIGHT），WHEN 该攻击被选中进入 TELEGRAPHING，THEN telegraph_timer 初始值 = 0.6s（override wins over T_default）。
- [x] **AC-11** GIVEN AttackData.telegraph_duration_override = 0，attack_type=HEAVY，WHEN 该攻击被选中，THEN telegraph_timer 初始值 = 1.2s（T_default[HEAVY] from BossData）。
- [x] **AC-23** GIVEN 系统 STAGGERED，WHEN 同帧收到 `stagger_ended` 和 `boss_defeated`，THEN 系统进入 DEFEATED（boss_defeated 优先）；sequence_index 不推进。
- [x] **AC-24** GIVEN 系统 DEFEATED，WHEN 接收 `stagger_ended`、`parry_succeeded`、`boss_phase_changed`、`parry_failed` 任意信号，THEN 所有信号被忽略；状态保持 DEFEATED；不发出 `attack_telegraphed`。

---

## Implementation Notes

*Derived from ADR-0004, ADR-0002, ADR-0005:*

**AC-11 / TR-BSM-003 — BossData schema for T_default (Option A: Dictionary on BossData)**

Add to `game/scripts/data/boss_data.gd`:
```gdscript
## Default telegraph duration per AttackType. Key: int(GameEnums.AttackType), value: float (seconds).
## 0 = fallback (should not happen in production — set values for all AttackTypes in the .tres asset).
## Example: { 0: 0.8, 1: 1.2, 2: 1.5 }  (LIGHT=0.8, HEAVY=1.2, SWEEP=1.5)
@export var default_telegraph_durations: Dictionary = {}

## Look up the default telegraph duration for a given AttackType.
## Returns the fallback constant if the type is not in the dictionary.
func get_default_telegraph_duration(type: GameEnums.AttackType) -> float:
    return float(default_telegraph_durations.get(int(type), 0.1))
```

Update `_get_effective_telegraph_duration` in `boss_state_machine.gd` to replace the `push_error` + fallback with:
```gdscript
func _get_effective_telegraph_duration(attack: AttackData) -> float:
    if attack.telegraph_duration_override > 0.0:
        return attack.telegraph_duration_override
    # TODO removed — Story 003 implements the real lookup via TR-BSM-003.
    return _boss_data.get_default_telegraph_duration(attack.attack_type)
```

Test fixture setup for AC-10/AC-11: when building BossData in tests, populate
`boss.default_telegraph_durations = { int(GameEnums.AttackType.HEAVY): 1.2 }` for the
`T_default[HEAVY] = 1.2s` assertion. For `override = 0.6` (AC-10), set
`attack.telegraph_duration_override = 0.6` — the dictionary entry is irrelevant since override wins.

**DEFEATED terminal entry:**
```gdscript
func _on_boss_defeated() -> void:
    # Immediate regardless of current state — boss_defeated is highest priority
    _transition_to(BehaviorState.DEFEATED)

func _enter_state(state: BehaviorState) -> void:
    match state:
        BehaviorState.DEFEATED:
            idle_timer = 0.0
            internal_telegraph_timer = 0.0
            # Signal cleanup for ATTACKING→DEFEATED is handled by _exit_state(ATTACKING).
            # Do NOT re-attempt disconnect here — _anim_player may be null in tests.
```

**All signal handlers guard DEFEATED automatically:**
Existing guards already cover DEFEATED:
- `_on_stagger_ended`: `if behavior_state != BehaviorState.STAGGERED: return` — DEFEATED returns ✅
- `_on_parry_succeeded`: `if behavior_state != BehaviorState.TELEGRAPHING: return` — DEFEATED returns ✅
- `_on_parry_failed`: `pass` — no-op regardless ✅
- `_on_attack_animation_done`: `if behavior_state != BehaviorState.ATTACKING: return` — DEFEATED returns ✅

No additional DEFEATED guards are needed in existing handlers.

Subscribe `boss_defeated` in `_ready()` (add after the three existing subscriptions):
```gdscript
@warning_ignore("unsafe_property_access")
_event_bus.boss_defeated.connect(_on_boss_defeated)
```

**Same-frame priority (AC-23):**
The existing `_on_stagger_ended` guard (`if behavior_state != STAGGERED: return`) already handles the case where `boss_defeated` fires first (BSM enters DEFEATED, then `stagger_ended` fires and returns immediately). No additional code needed — test should call `_on_boss_defeated()` then `_on_stagger_ended()` and verify sequence_index unchanged.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002: STAGGERED/stagger_ended normal path
- Story 004: boss_phase_changed handling
- Story 005: data validation (empty sequence, clamp)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-002-2026-06-04.md` S002-F01 test specs.*

- **AC-06**: boss_defeated from any state → immediate DEFEATED + timers cleared
  - Given: behavior_state=TELEGRAPHING; internal_telegraph_timer=0.5s
  - When: `_on_boss_defeated()` called
  - Then: behavior_state=DEFEATED; internal_telegraph_timer=0.0; idle_timer=0.0; no `attack_telegraphed` emitted in next 3s
  - Edge cases: test from IDLE, ATTACKING, STAGGERED, PHASE_TRANSITION

- **AC-10**: telegraph_duration_override wins when > 0
  - Given: AttackData(type=LIGHT, telegraph_duration_override=0.6); T_default[LIGHT]=0.8
  - When: attack selected → TELEGRAPHING
  - Then: internal_telegraph_timer=0.6 (not 0.8)

- **AC-11**: T_default used when override=0
  - Given: AttackData(type=HEAVY, telegraph_duration_override=0.0); T_default[HEAVY]=1.2
  - When: attack selected → TELEGRAPHING
  - Then: internal_telegraph_timer=1.2

- **AC-23**: Same-frame boss_defeated + stagger_ended: DEFEATED wins
  - Given: behavior_state=STAGGERED; sequence_index=1
  - When: `_on_stagger_ended()` AND `_on_boss_defeated()` both called same frame
  - Then: behavior_state=DEFEATED; sequence_index=1 (unchanged — stagger_ended did not advance)

- **AC-24**: DEFEATED ignores all subsequent signals
  - Given: behavior_state=DEFEATED
  - When: call `_on_stagger_ended()`, `_on_parry_succeeded(LIGHT)`, `_on_parry_failed(LIGHT)`
  - Then: behavior_state still DEFEATED; `attack_telegraphed` not emitted; no state change
  - Note: `_on_boss_phase_changed` handler is Story 004's deliverable — do NOT call it in Story 003 tests.
    The `boss_phase_changed` subscription will be added in Story 004; DEFEATED guard for that handler
    is also Story 004's responsibility.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/boss_state_machine/test_bsm_defeated.gd` — must exist and pass

**Status**: [x] Complete — `game/tests/unit/boss_state_machine/test_bsm_defeated.gd` — 11/11 passing (2026-06-06)

---

## Dependencies

- Depends on: Story 002 (STAGGERED state required for AC-23) ✅ Complete
- Unlocks: Story 004 (phase transitions can now build on full state set)

---

## Completion Notes

**Completed**: 2026-06-06
**Criteria**: 5/5 passing
**Deviations**: None — ADR-0004/0002/0001/0005 全部合规；无字面量时长值
**Test Evidence**: Logic story — `game/tests/unit/boss_state_machine/test_bsm_defeated.gd` — 11/11 passing (38/38 BSM total)
**Code Review**: Complete — CHANGES REQUIRED → 6 fixes applied (typed dict, dead constant removed, _exit_state DEFEATED branch, timer assertions, pending_anim_fallback assertion, typed array literal) → APPROVED (2026-06-06)
**Files modified**: game/scripts/data/boss_data.gd (Dictionary[int,float] + get_default_telegraph_duration), game/scripts/feature/boss_state_machine.gd (DEFEATED state, boss_defeated handler, real T_default lookup)
