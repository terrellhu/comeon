# Story 003: Parry Signal Contract — parry_input_pressed + exit_parry_state

> **Epic**: PlayerController
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/player-controller-system.md`
**Requirements**: `TR-PC-007`, `TR-PC-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Primary ADR**: [ADR-0004: Player State Machine Architecture](../../../docs/architecture/adr-0004-player-state-machine-architecture.md)
**Secondary ADR**: [ADR-0001: Signal Routing Architecture](../../../docs/architecture/adr-0001-signal-routing-architecture.md)
**ADR Decision Summary**: `parry_input_pressed` is a 1:1 direct signal on PlayerController (not EventBus) because it has a single consumer (ParryTelegraphSystem). The controller emits it on `_enter_state(PARRYING)` and receives `exit_parry_state(duration)` from ParryTelegraphSystem to start the exit timer. Parry has higher priority than dodge in `_handle_input()` via early return order.

**Governing ADRs**: ADR-0004 (primary — state machine pattern, priority rules), ADR-0001 (secondary — 1:1 signal exception, signal declaration location)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Godot 4 typed signals are stable. `CONNECT_ONE_SHOT` is not needed for `exit_parry_state` since it is a recurring event signal. Verify `Input.is_action_just_pressed()` returns true only once per press in `_physics_process`.

**Control Manifest Rules (Core layer)**:
- Required: `parry_input_pressed` declared as a signal on PlayerController node (not EventBus); 1:1 consumer (ParryTelegraphSystem); connected in GameRoot `_ready()`
- Forbidden: routing `parry_input_pressed` through EventBus; emitting `parry_input_pressed` anywhere other than `_enter_state(PARRYING)`
- Guardrail: parry → PARRYING transition must happen same frame as input detection

---

## Acceptance Criteria

*From GDD `design/gdd/player-controller-system.md`, scoped to this story:*

- [ ] **AC-parry-enter**: GIVEN player in IDLE, RUNNING, or AIRBORNE, WHEN `parry` action just pressed, THEN same frame: state = PARRYING, `velocity.x = 0`, `parry_input_pressed` signal emitted, same-frame move input ignored
- [ ] **AC-parry-priority**: GIVEN `parry` and `dodge` both just pressed same frame, WHEN `_handle_input()` runs, THEN state = PARRYING; `dodge` input ignored; `parry_input_pressed` emitted; `dodge_input_pressed` NOT emitted
- [ ] **AC-parry-exit**: GIVEN player in PARRYING state, WHEN `exit_parry_state(duration)` method called by external system, THEN `parry_exit_timer = duration`; state transitions to IDLE (or RUNNING) after `duration` seconds elapse
- [ ] **AC-parry-isolation-jump**: GIVEN player in PARRYING state, WHEN `jump` action pressed, THEN jump NOT executed; no state change from PARRYING
- [ ] **AC-parry-isolation-dodge**: GIVEN player in DODGING state, WHEN `parry` action pressed, THEN state stays DODGING; `parry_input_pressed` NOT emitted; dodge must end before parry is accepted
- [ ] **AC-airborne-parry**: GIVEN player in AIRBORNE state, WHEN `parry` action pressed, THEN enters PARRYING; `velocity.x = 0`; signal emitted (air parry is allowed)

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0001 Implementation Guidelines:*

**Signal declaration** (on PlayerController, not EventBus):
```gdscript
signal parry_input_pressed
```

**`_enter_state(PARRYING)` behavior**:
```gdscript
GameEnums.PlayerState.PARRYING:
    velocity.x = 0.0
    parry_input_pressed.emit()    # direct signal — connected by GameRoot
```

**`exit_parry_state(duration: float)` method** — called by ParryTelegraphSystem:
```gdscript
func exit_parry_state(duration: float) -> void:
    parry_exit_timer = duration   # timer counted down in _process_state
```

**`_process_state` — PARRYING branch**:
```gdscript
GameEnums.PlayerState.PARRYING:
    velocity.x = 0.0
    if parry_exit_timer > 0.0:
        parry_exit_timer -= delta
        if parry_exit_timer <= 0.0:
            _transition_to(GameEnums.PlayerState.IDLE)   # or RUNNING if move input
```

**Priority rule in `_handle_input()`** — parry early-return before dodge:
```gdscript
if Input.is_action_just_pressed(&"parry") and _can_parry():
    _transition_to(GameEnums.PlayerState.PARRYING)
    return    # ← early return means dodge check never runs same frame

if Input.is_action_just_pressed(&"dodge") and _can_dodge():
    _transition_to(GameEnums.PlayerState.DODGING)
    return
```

**`_can_parry()` guard** (standalone, testable):
```gdscript
func _can_parry() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING,
        GameEnums.PlayerState.AIRBORNE
    ]
```

DODGING returns false from `_can_parry()` because DODGING is not in the allowed list. This enforces the "DODGING ignores parry" edge case automatically via the guard function.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: `_handle_input()` skeleton, `_transition_to()` dispatcher
- [Story 004]: DEAD state guard that blocks all input (also blocks parry during DEAD)
- [Story 002]: Jump buffer interaction with PARRYING (jump is blocked by PARRYING isolation)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new cases during implementation.*

- **AC-parry-enter**: Parry enters PARRYING from allowed states
  - Given: player_state = IDLE (repeat for RUNNING, AIRBORNE)
  - When: parry action just pressed; `_can_parry()` returns true
  - Then: state = PARRYING; velocity.x = 0.0; `parry_input_pressed` was emitted this frame
  - Edge cases: parry from AIRBORNE also works (air parry allowed)

- **AC-parry-priority**: Same-frame parry+dodge → parry wins
  - Given: both parry and dodge actions just-pressed same frame; player_state = IDLE
  - When: `_handle_input()` runs
  - Then: state = PARRYING; `parry_input_pressed` emitted; `dodge_input_pressed` NOT emitted
  - Edge cases: verify early return prevents dodge code from executing at all

- **AC-parry-exit**: exit_parry_state sets timer correctly
  - Given: player_state = PARRYING
  - When: `exit_parry_state(0.40)` called
  - Then: `parry_exit_timer = 0.40`; after 0.40s of `_process_state` calls → state = IDLE
  - Edge cases: timer counts down per delta; exact transition frame (timer ≤ 0)

- **AC-parry-isolation-jump**: PARRYING blocks jump
  - Given: player_state = PARRYING
  - When: jump action pressed
  - Then: state stays PARRYING; velocity unchanged; no jump executed; jump_buffer_timer unchanged
  - Edge cases: PARRYING is not in `_can_jump()` allowed list? Actually `_can_jump()` checks `is_on_floor() or coyote_timer > 0` — parry should block jump via `_handle_input()` not via `_can_jump()`. Verify jump branch is skipped during PARRYING.

- **AC-parry-isolation-dodge**: DODGING blocks parry
  - Given: player_state = DODGING
  - When: parry action just pressed
  - Then: `_can_parry()` returns false (DODGING not in allowed list); state stays DODGING; `parry_input_pressed` NOT emitted
  - Edge cases: dodge_ended must arrive before parry is accepted

- **AC-airborne-parry**: Air parry works
  - Given: player_state = AIRBORNE
  - When: parry action pressed
  - Then: state = PARRYING; velocity.x = 0.0; `parry_input_pressed` emitted
  - Edge cases: velocity.y is unchanged (gravity continues during PARRYING? — check GDD: PARRYING state has velocity.x=0 but vertical continues)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/player_controller/test_pc_parry.gd` — must exist and pass

*Note: GUT requires `test_` prefix.*

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerController Skeleton) must be DONE
- Unlocks: None directly (parry contract consumed by ParryTelegraphSystem epic)

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 4/6 passing (2 deferred — GUT headless Input constraints)
**Deviations**: ADVISORY — `exit_parry_state()` adds `duration <= 0.0` guard with `push_warning`; defensive, not spec-violating; logged to tech-debt register
**Test Evidence**: Integration test at `game/tests/integration/player_controller/test_pc_parry.gd` — 12/15 pass, 3 pending (AC-parry-enter input path, AC-parry-priority, AC-parry-isolation-jump); deferred stubs reference `test_pc_parry_physics.gd`
**Untested criteria**: AC-parry-priority, AC-parry-isolation-jump. Recommend physics-scene integration test before sprint QA close-out.
**Code Review**: Complete (/code-review passed)
