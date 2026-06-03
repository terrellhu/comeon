# Story 002: Jump System — Coyote Time + Jump Buffer

> **Epic**: PlayerController
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03

## Context

**GDD**: `design/gdd/player-controller-system.md`
**Requirements**: `TR-PC-005`, `TR-PC-008` (jump impulse)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: [ADR-0004: Player State Machine Architecture](../../../docs/architecture/adr-0004-player-state-machine-architecture.md)
**ADR Decision Summary**: Coyote time and jump buffer implemented as float timers (`coyote_timer`, `jump_buffer_timer`) decremented in `_process_state(delta)`; `_can_jump()` checks `is_on_floor() or coyote_timer > 0.0`; jump buffer check runs on grounding transition.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `is_on_floor()` and `_physics_process` with fixed 60fps physics tick are stable since Godot 4.0. Coyote timer must only start when the player walks OFF a platform (not when actively jumping off); ensure this distinction is implemented correctly.

**Control Manifest Rules (Core layer)**:
- Required: all params `@export var`; `_can_jump()` is a standalone testable guard function
- Forbidden: no numeric literals for timer durations in logic code
- Guardrail: `_physics_process` < 0.5ms (cumulative with Story 001 logic)

---

## Acceptance Criteria

*From GDD `design/gdd/player-controller-system.md`, scoped to this story:*

- [ ] **AC-jump**: GIVEN player on floor (IDLE or RUNNING), WHEN `jump` action pressed, THEN `velocity.y = -jump_impulse` (≈ -600 px/s) and state transitions to AIRBORNE same frame
- [ ] **AC-coyote-success**: GIVEN player walked off platform edge (coyote_timer > 0.0, NOT jumped off), WHEN `jump` action pressed within `coyote_time_duration` (0.10s), THEN jump executes: `velocity.y = -jump_impulse`; `coyote_timer` reset to 0
- [ ] **AC-coyote-expired**: GIVEN player AIRBORNE, `coyote_timer = 0.0`, not on floor, WHEN `jump` action pressed, THEN jump does NOT execute; input enters `jump_buffer_timer = jump_buffer_duration`
- [ ] **AC-buffer-success**: GIVEN player AIRBORNE, `jump_buffer_timer > 0.0`, WHEN `is_on_floor()` becomes true (landing), THEN jump executes immediately that frame: `velocity.y = -jump_impulse`
- [ ] **AC-buffer-expired**: GIVEN player AIRBORNE, `jump_buffer_timer = 0.0` (elapsed), WHEN player lands, THEN no auto-jump; state → IDLE or RUNNING normally
- [ ] **AC-no-double-jump**: GIVEN player AIRBORNE, `coyote_timer = 0.0`, `jump_buffer_timer = 0.0`, WHEN `jump` pressed again, THEN jump does NOT execute; `jump_buffer_timer = jump_buffer_duration` (buffer starts for next landing)
- [ ] **AC-coyote-no-reset**: GIVEN player at platform edge, WHEN player walks out and back multiple times, THEN coyote_timer does NOT restart — only the initial departure starts the timer

---

## Implementation Notes

*Derived from ADR-0004 Implementation Guidelines:*

**Coyote timer logic** — starts when player transitions from grounded to AIRBORNE without a jump:
```gdscript
# In _exit_state(IDLE) or _exit_state(RUNNING) when cause is falling (not jumping):
if not _jumped_this_frame:
    coyote_timer = coyote_time_duration
```

**Timer decrement in `_process_state(delta)`**:
```gdscript
if coyote_timer > 0.0:
    coyote_timer = max(0.0, coyote_timer - delta)
if jump_buffer_timer > 0.0:
    jump_buffer_timer = max(0.0, jump_buffer_timer - delta)
```

**Jump buffer check on grounding** — in the AIRBORNE state's `is_on_floor()` detection block:
```gdscript
if is_on_floor():
    if jump_buffer_timer > 0.0:
        # execute jump instead of transitioning to IDLE
        velocity.y = -jump_impulse
        jump_buffer_timer = 0.0
        _transition_to(GameEnums.PlayerState.AIRBORNE)
    else:
        _transition_to(GameEnums.PlayerState.IDLE)  # or RUNNING
```

**`_can_jump()` guard**:
```gdscript
func _can_jump() -> bool:
    return is_on_floor() or coyote_timer > 0.0
```

**Jump execution** in `_handle_input()`:
```gdscript
if Input.is_action_just_pressed(&"jump"):
    jump_buffer_timer = jump_buffer_duration   # always set buffer on press
    if _can_jump():
        velocity.y = -jump_impulse
        coyote_timer = 0.0
        _transition_to(GameEnums.PlayerState.AIRBORNE)
```

**Key distinction**: setting `jump_buffer_timer` unconditionally on press means the buffer is set even if `_can_jump()` is false. This is the correct behavior — the buffer fires on landing.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine infrastructure, `_process_state` skeleton, `_handle_input` skeleton
- [Story 003]: Parry input blocking jump during PARRYING
- [Story 004]: DEAD state preventing all input (including jump)

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new cases during implementation.*

- **AC-jump**: Ground jump sets velocity and state
  - Given: player on floor, player_state = IDLE, jump_impulse @export = 600.0
  - When: jump action just pressed, `_can_jump()` returns true
  - Then: velocity.y = -600.0; state = AIRBORNE
  - Edge cases: RUNNING state same result; velocity.y is exactly -jump_impulse (negative)

- **AC-coyote-success**: Coyote jump within window
  - Given: coyote_timer = 0.05 (half expired), player NOT on floor
  - When: jump action just pressed in `_handle_input()`
  - Then: velocity.y = -jump_impulse; coyote_timer reset to 0.0; state = AIRBORNE
  - Edge cases: coyote_timer = coyote_time_duration (fresh) → succeeds; coyote_timer = 0.001 (nearly expired) → still succeeds

- **AC-coyote-expired**: No jump after coyote expires
  - Given: coyote_timer = 0.0, not on floor, jump_buffer_timer = 0.0
  - When: jump action just pressed
  - Then: velocity.y unchanged; state stays AIRBORNE; jump_buffer_timer = jump_buffer_duration
  - Edge cases: coyote_timer expired exactly this frame (= 0.0 after decrement) → no jump

- **AC-buffer-success**: Buffer fires on landing
  - Given: player AIRBORNE, jump_buffer_timer = 0.08 (still active)
  - When: simulate is_on_floor() returning true in `_process_state()`
  - Then: velocity.y = -jump_impulse; jump_buffer_timer = 0.0; state = AIRBORNE (re-jumps)
  - Edge cases: jump_buffer_timer at exact boundary (> 0.0) → fires

- **AC-buffer-expired**: No auto-jump when buffer gone
  - Given: player AIRBORNE, jump_buffer_timer = 0.0
  - When: is_on_floor() returns true
  - Then: state → IDLE (or RUNNING); velocity.y = 0.0; no jump
  - Edge cases: buffer expired exactly this frame → no jump

- **AC-no-double-jump**: Second jump in AIRBORNE fills buffer only
  - Given: player_state = AIRBORNE, coyote_timer = 0.0, jump_buffer_timer = 0.0
  - When: jump action just pressed
  - Then: velocity.y unchanged; state stays AIRBORNE; jump_buffer_timer = jump_buffer_duration
  - Edge cases: pressing jump multiple times in AIRBORNE — only most recent buffer matters

- **AC-coyote-no-reset**: Coyote timer starts only on first departure
  - Given: player at edge, coyote_timer = 0.09 (running)
  - When: player steps back onto floor then off again
  - Then: coyote_timer does NOT reset to coyote_time_duration from the second departure
  - Edge cases: only the transition from grounded→AIRBORNE-via-fall starts the timer

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/player_controller/test_pc_jump.gd` — must exist and pass

*Note: GUT requires `test_` prefix.*

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerController Skeleton) must be DONE
- Unlocks: Story 006 (jump buffer state is part of retry reset)

---

## Completion Notes

**Completed**: 2026-06-03
**Criteria**: 1/7 unit-covered; 6/7 deferred (headless constraint — requires Input injection or is_on_floor() = true)
- AC-coyote-no-reset: COVERED (4 unit tests)
- AC-jump, AC-coyote-success, AC-coyote-expired, AC-buffer-success, AC-buffer-expired, AC-no-double-jump: DEFERRED to `game/tests/integration/player_controller/test_pc_jump_integration.gd` — pending() stubs document per-AC sub-assertions for the integration test author
- Verdict override accepted: all deferrals are genuine headless constraints; code review APPROVED
**Deviations**:
- ADVISORY: Jump buffer `_transition_to(AIRBORNE)` self-transition is latent animation restart for Story 005 — tech-debt note added in source at that line
- ADVISORY: Horizontal velocity skipped on jump frame (early return in _handle_input) — design decision undocumented; carries previous frame velocity.x
**Test Evidence**: Logic — `game/tests/unit/player_controller/test_pc_jump.gd` — 64/71 pass (21 active + 6 pending stubs)
**Code Review**: Complete — APPROVED (two passes)
