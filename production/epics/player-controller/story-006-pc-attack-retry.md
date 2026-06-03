# Story 006: Attack Input Forwarding + Retry Reset

> **Epic**: PlayerController
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: —

## Context

**GDD**: `design/gdd/player-controller-system.md`
**Requirements**: `TR-PC-006`, `TR-PC-010` (reset_for_retry aspect), `TR-PC-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Primary ADR**: [ADR-0004: Player State Machine Architecture](../../../docs/architecture/adr-0004-player-state-machine-architecture.md)
**Secondary ADR**: [ADR-0003: RetryContext and Scene Reset Strategy](../../../docs/architecture/adr-0003-retrycontext-scene-reset.md)
**ADR Decision Summary**: `attack_input_pressed` is a 1:1 direct signal on PlayerController (not EventBus), consumed by CounterAttackComboSystem. Attack does NOT trigger a state change in the controller — it is a pure forwarded impulse. `reset_for_retry(ctx: Dictionary)` resets all stateful variables to post-death-screen initial values; the 2.0s retry invulnerability is granted separately by InstantRetrySystem after `SceneTree.paused = false`.

**Governing ADRs**: ADR-0004 (primary — attack forwarding pattern, no-state-change rule), ADR-0003 (secondary — reset_for_retry contract, required variable list)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: All stable APIs. Performance verification (`_physics_process < 0.5ms`) should be done with Godot's built-in Profiler (Scripts tab) on a native build — headless/editor profiling gives inaccurate results.

**Control Manifest Rules (Core layer)**:
- Required: `attack_input_pressed` declared on PlayerController (not EventBus); attack emits signal only, no state change; `reset_for_retry(ctx: Dictionary)` resets player_state, velocity, position, facing_direction, all timers
- Forbidden: routing `attack_input_pressed` through EventBus; any state change on attack input; omitting any stateful variable from `reset_for_retry()`
- Guardrail: `_physics_process` < 0.5ms verified post-full-implementation

---

## Acceptance Criteria

*From GDD `design/gdd/player-controller-system.md`, scoped to this story:*

- [ ] **AC-attack-idle**: GIVEN player_state = IDLE, WHEN `attack` action pressed, THEN `attack_input_pressed` emitted same frame; state stays IDLE; velocity unchanged
- [ ] **AC-attack-running**: GIVEN player_state = RUNNING (`velocity.x = move_speed`), WHEN `attack` action pressed, THEN `attack_input_pressed` emitted; state stays RUNNING; `velocity.x` stays `move_speed` (attack does NOT lock movement)
- [ ] **AC-attack-airborne**: GIVEN player_state = AIRBORNE, WHEN `attack` action pressed, THEN `attack_input_pressed` emitted; state stays AIRBORNE; `velocity.y` unchanged
- [ ] **AC-attack-blocked-parrying**: GIVEN player_state = PARRYING, WHEN `attack` action pressed, THEN `attack_input_pressed` NOT emitted; no state change
- [ ] **AC-attack-blocked-dodging**: GIVEN player_state = DODGING, WHEN `attack` action pressed, THEN `attack_input_pressed` NOT emitted; no state change
- [ ] **AC-attack-blocked-hit-stun**: GIVEN player_state = HIT_STUN, WHEN `attack` action pressed, THEN `attack_input_pressed` NOT emitted; no state change
- [ ] **AC-attack-blocked-dead**: GIVEN player_state = DEAD, WHEN `attack` action pressed, THEN `attack_input_pressed` NOT emitted; no state change (DEAD guard in `_handle_input()`)
- [ ] **AC-retry-reset**: GIVEN player in DEAD state with dirty values (`coyote_timer = 0.08`, `jump_buffer_timer = 0.10`, `hit_stun_timer = 0.20`, `parry_exit_timer = 0.30`, `position ≠ spawn_position`, `facing_direction = -1`), WHEN `reset_for_retry(ctx)` called, THEN `player_state = IDLE`; `velocity = Vector2.ZERO`; `position = spawn_position`; `facing_direction = 1`; all timers = 0.0
- [ ] **AC-retry-no-invuln**: GIVEN `reset_for_retry(ctx)` called, WHEN reset completes, THEN NO invulnerability timer is set by PlayerController — invuln is InstantRetrySystem's responsibility post-resume
- [ ] **AC-performance**: GIVEN full PlayerController implementation across all 6 stories, WHEN Godot Profiler (native build) measures `_physics_process` over 300 frames, THEN average < 0.5ms; no single frame > 1.0ms under normal gameplay

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0003 Implementation Guidelines:*

**Signal declaration** (on PlayerController, not EventBus):
```gdscript
signal attack_input_pressed
```

**Attack forwarding in `_handle_input()`** (after dodge check, before horizontal move):
```gdscript
if Input.is_action_just_pressed(&"attack") and _can_attack():
    attack_input_pressed.emit()
    # NO state change — attack is a forwarded impulse only
    # NO velocity change — CounterAttackComboSystem handles the response
```

**`_can_attack()` guard** (standalone, testable):
```gdscript
func _can_attack() -> bool:
    return player_state in [
        GameEnums.PlayerState.IDLE,
        GameEnums.PlayerState.RUNNING,
        GameEnums.PlayerState.AIRBORNE
    ]
```

PARRYING, DODGING, HIT_STUN, and DEAD are all excluded. DEAD is already handled by the early return at the top of `_handle_input()`, but `_can_attack()` returning false for DEAD makes the guard self-documenting and testable in isolation.

**`reset_for_retry(ctx: Dictionary)` — complete required variable list** (per ADR-0003):
```gdscript
func reset_for_retry(ctx: Dictionary) -> void:
    player_state = GameEnums.PlayerState.IDLE   # direct assignment — intentional exception to _transition_to rule
    velocity = Vector2.ZERO
    position = spawn_position
    facing_direction = 1
    coyote_timer = 0.0
    jump_buffer_timer = 0.0
    hit_stun_timer = 0.0
    parry_exit_timer = 0.0
    _prev_hp = 0.0   # reset HP tracking so first hp_changed after retry isn't misread as damage
```

**Critical**: The direct `player_state =` assignment in `reset_for_retry()` bypasses `_transition_to()`. This is the intentional exception documented in ADR-0003 — `_enter_state()` and `_exit_state()` hooks must NOT fire during reset (they would trigger signal emissions into a paused scene tree). Add a comment marking this as intentional.

**Invulnerability**: Do NOT start any invuln timer in `reset_for_retry()`. InstantRetrySystem calls `reset_for_retry()` during `SceneTree.paused = true`; the invuln timer starts after `SceneTree.paused = false` via a separate mechanism.

**Performance verification**: After all 6 stories are implemented, open the Godot Profiler (native Windows build, not editor), run 300 frames of active gameplay with state transitions, and confirm `_physics_process` < 0.5ms average. Document the measured value in the story's test evidence.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: `_handle_input()` skeleton, DEAD guard, `_can_attack()` structure
- [Story 004]: DEAD state entry (Story 004 establishes DEAD; this story verifies it blocks attack)
- InstantRetrySystem: subscribes to reset signal and calls `reset_for_retry()`; retry invuln timer start

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new cases during implementation.*

- **AC-attack-idle**: Attack from IDLE emits signal, no state change
  - Given: player_state = IDLE
  - When: attack action just pressed
  - Then: `attack_input_pressed` emitted once; player_state still IDLE; velocity unchanged
  - Edge cases: signal emitted exactly once per press (not per frame)

- **AC-attack-running**: Attack from RUNNING preserves velocity
  - Given: player_state = RUNNING, velocity.x = 340.0 (move_speed)
  - When: attack action just pressed
  - Then: `attack_input_pressed` emitted; player_state still RUNNING; velocity.x = 340.0 (unchanged)
  - Edge cases: attack and move input same frame → attack emits, movement continues

- **AC-attack-airborne**: Attack from AIRBORNE emits signal
  - Given: player_state = AIRBORNE
  - When: attack action just pressed
  - Then: `attack_input_pressed` emitted; player_state still AIRBORNE; velocity.y unchanged
  - Edge cases: velocity.y still accumulating gravity next frame (no lock)

- **AC-attack-blocked**: All 4 blocked states
  - Given: player_state = PARRYING (repeat for DODGING, HIT_STUN, DEAD)
  - When: attack action just pressed
  - Then: `attack_input_pressed` NOT emitted; player_state unchanged
  - Edge cases: test all 4 states individually; DEAD hits the early return before `_can_attack()` check

- **AC-retry-reset**: Full reset of all stateful variables
  - Given: player_state = DEAD; velocity = Vector2(150, -200); position = Vector2(300, 0); facing_direction = -1; coyote_timer = 0.08; jump_buffer_timer = 0.10; hit_stun_timer = 0.20; parry_exit_timer = 0.30; spawn_position = Vector2(0, 0)
  - When: `reset_for_retry({})` called (ctx can be empty for PlayerController — it doesn't use boss data)
  - Then: player_state = IDLE; velocity = Vector2.ZERO; position = Vector2(0,0); facing_direction = 1; all 4 timers = 0.0
  - Edge cases: verify each variable individually; none missed

- **AC-retry-no-invuln**: Retry reset does not start invuln
  - Given: PlayerController with no invuln-related field
  - When: `reset_for_retry({})` called
  - Then: no invuln timer or variable modified in PlayerController; InstantRetrySystem is sole owner
  - Edge cases: if invuln is added to PlayerController later, add it to this test

- **AC-performance**: _physics_process < 0.5ms
  - Given: full 6-story implementation, native Windows build, 300-frame session
  - When: Godot Profiler → Scripts → PlayerController._physics_process measured
  - Then: average time < 0.5ms; document measured value in test evidence file
  - Edge cases: measure under state transitions (worst case for branch prediction)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/player_controller/test_pc_attack_retry.gd` — must exist and pass

*Note: GUT requires `test_` prefix.*

**Performance evidence**: Godot Profiler screenshot or logged measurement documenting `_physics_process` average < 0.5ms on native Windows build.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerController Skeleton) must be DONE; Story 004 (DEAD state) must be DONE
- Unlocks: Epic Definition of Done — all stories complete → PlayerController epic closeable
