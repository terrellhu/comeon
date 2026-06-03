# Story 005: Dodge Signal Contract — dodge_input_pressed + Physics Pause

> **Epic**: PlayerController
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/player-controller-system.md`
**Requirements**: `TR-PC-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Primary ADR**: [ADR-0004: Player State Machine Architecture](../../../docs/architecture/adr-0004-player-state-machine-architecture.md)
**Secondary ADR**: [ADR-0001: Signal Routing Architecture](../../../docs/architecture/adr-0001-signal-routing-architecture.md)
**ADR Decision Summary**: `dodge_input_pressed(direction: int)` is a 1:1 direct signal on PlayerController (not EventBus). Controller enters DODGING state and pauses its own physics (skips velocity updates and move_and_slide does not move the player since DodgeSystem controls position directly). Controller resumes on `dodge_ended` signal from DodgeSystem.

**Governing ADRs**: ADR-0004 (primary — DODGING state behavior, physics pause pattern), ADR-0001 (secondary — 1:1 signal exception for `dodge_input_pressed`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: "Physics pause" here means the controller does NOT set velocity or call move_and_slide during DODGING — DodgeSystem moves the CharacterBody2D directly. This is a cooperative handoff, not a Godot engine-level pause. Confirm `CharacterBody2D.move_and_slide()` behavior when DodgeSystem calls `move_and_slide()` on the same node — only one caller should drive it per frame.

**Control Manifest Rules (Core layer)**:
- Required: `dodge_input_pressed(direction: int)` declared on PlayerController (not EventBus); physics pause during DODGING by skipping velocity update + move_and_slide; `dodge_ended` received via signal connection
- Forbidden: routing `dodge_input_pressed` through EventBus; calling `move_and_slide()` during DODGING from PlayerController's `_physics_process`
- Guardrail: `_can_dodge()` allows only IDLE/RUNNING (not AIRBORNE — air dodge not in GDD)

---

## Acceptance Criteria

*From GDD `design/gdd/player-controller-system.md`, scoped to this story:*

- [ ] **AC-dodge-idle**: GIVEN player_state = IDLE, `facing_direction = 1`, no move input, WHEN `dodge` action pressed, THEN state = DODGING; `dodge_input_pressed(1)` emitted
- [ ] **AC-dodge-running**: GIVEN player_state = RUNNING, `move_input_direction = -1` (moving left), WHEN `dodge` action pressed, THEN state = DODGING; `dodge_input_pressed(-1)` emitted
- [ ] **AC-dodge-physics-pause**: GIVEN player in DODGING state, WHEN `_physics_process` runs, THEN PlayerController does NOT update `velocity` and does NOT call `move_and_slide()` — position controlled by DodgeSystem
- [ ] **AC-dodge-ended**: GIVEN player in DODGING, WHEN `dodge_ended` signal received from DodgeSystem, THEN state → IDLE (no move input) or RUNNING (move input held); physics resumes normally
- [ ] **AC-dead-overrides-dodge**: GIVEN player_state = DODGING, WHEN `player_died` signal received, THEN state = DEAD immediately; `velocity = Vector2.ZERO`; DodgeSystem position control revoked
- [ ] **AC-dodge-facing-locked**: GIVEN player_state = DODGING, WHEN horizontal move input detected, THEN `facing_direction` does NOT change during DODGING

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0001 Implementation Guidelines:*

**Signal declaration** (on PlayerController, not EventBus):
```gdscript
signal dodge_input_pressed(direction: int)
```

**`_can_dodge()` guard** (standalone, testable):
```gdscript
func _can_dodge() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING
    ]
```

AIRBORNE is NOT in the allowed list — air dodge is not in the GDD.

**Dodge direction logic** in `_handle_input()`:
```gdscript
if Input.is_action_just_pressed(&"dodge") and _can_dodge():
    var dodge_dir: int = move_input_direction if move_input_direction != 0 else facing_direction
    _transition_to(GameEnums.PlayerState.DODGING)
    dodge_input_pressed.emit(dodge_dir)   # emit AFTER transition (state is set)
    return
```

**`_enter_state(DODGING)`**: No special velocity assignment — DodgeSystem takes over immediately after signal.

**`_process_state(delta)` — DODGING branch**: Skip all velocity updates. Do NOT call `move_and_slide()` from controller.

**Physics pause implementation** — conditional in `_physics_process`:
```gdscript
func _physics_process(delta: float) -> void:
    _handle_input()
    _process_state(delta)
    if player_state != GameEnums.PlayerState.DODGING:
        move_and_slide()   # DodgeSystem drives position during DODGING
```

**`dodge_ended` subscription** — in `_ready()` or via GameRoot wiring:
```gdscript
# Connected by GameRoot in _ready() — DodgeSystem.dodge_ended → PlayerController._on_dodge_ended
func _on_dodge_ended() -> void:
    if player_state == GameEnums.PlayerState.DODGING:
        _transition_to(GameEnums.PlayerState.IDLE)   # or RUNNING if move input held
```

The guard `if player_state == DODGING` prevents `dodge_ended` from firing if the player is already DEAD (player_died interrupted the dodge).

**`player_died` during DODGING** — handled by Story 004's `_on_player_died()` which calls `_transition_to(DEAD)` from any state; no special DODGING exit path needed here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: `_handle_input()` skeleton, `_transition_to()` dispatcher
- [Story 003]: Parry priority over dodge (same-frame parry+dodge → parry wins; early return before dodge check)
- [Story 004]: `player_died` interrupting DODGING (implemented in Story 004's `_on_player_died`)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new cases during implementation.*

- **AC-dodge-idle**: Dodge from IDLE uses facing direction
  - Given: player_state = IDLE, facing_direction = 1, no move input active
  - When: dodge action just pressed; `_can_dodge()` = true
  - Then: state = DODGING; `dodge_input_pressed(1)` was emitted
  - Edge cases: facing_direction = -1 → `dodge_input_pressed(-1)`

- **AC-dodge-running**: Dodge from RUNNING uses move direction
  - Given: player_state = RUNNING, move_input_direction = -1 (left)
  - When: dodge action just pressed
  - Then: state = DODGING; `dodge_input_pressed(-1)` emitted (move direction, not facing)
  - Edge cases: running right (move_input_direction = 1) → `dodge_input_pressed(1)`

- **AC-dodge-physics-pause**: Controller skips move_and_slide during DODGING
  - Given: player_state = DODGING
  - When: `_physics_process(delta)` runs
  - Then: `move_and_slide()` NOT called from PlayerController this frame; velocity NOT updated
  - Edge cases: verify via monitoring position — controller should not move the body

- **AC-dodge-ended**: Resume from DODGING on dodge_ended
  - Given: player_state = DODGING
  - When: `_on_dodge_ended()` called (dodge_ended signal received)
  - Then: state = IDLE (if no move input) or RUNNING (if move input held)
  - Edge cases: move input held during dodge → RUNNING on resume; no move input → IDLE

- **AC-dead-overrides-dodge**: player_died interrupts dodge
  - Given: player_state = DODGING
  - When: `player_died` signal received (→ `_on_player_died()`)
  - Then: state = DEAD; velocity = Vector2.ZERO
  - Edge cases: `dodge_ended` arriving after DEAD → guard prevents re-transition (state check in `_on_dodge_ended`)

- **AC-dodge-facing-locked**: Facing unchanged during DODGING
  - Given: player_state = DODGING, facing_direction = 1
  - When: move_left input detected in `_handle_input()`
  - Then: facing_direction stays 1; velocity.x not updated (DODGING is in the blocked list)
  - Edge cases: `_handle_input()` still runs during DODGING for DEAD check — verify other inputs are processed correctly

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/player_controller/test_pc_dodge.gd` — must exist and pass

*Note: GUT requires `test_` prefix.*

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerController Skeleton) must be DONE
- Unlocks: None directly (dodge contract consumed by DodgeSystem epic, future sprint)
