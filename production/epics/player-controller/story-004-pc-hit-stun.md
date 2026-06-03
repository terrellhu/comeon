# Story 004: HIT_STUN + DEAD State — Damage Response

> **Epic**: PlayerController
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-03



## Context

**GDD**: `design/gdd/player-controller-system.md`
**Requirements**: `TR-PC-009`, `TR-PC-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Primary ADR**: [ADR-0004: Player State Machine Architecture](../../../docs/architecture/adr-0004-player-state-machine-architecture.md)
**Secondary ADR**: [ADR-0003: RetryContext and Scene Reset Strategy](../../../docs/architecture/adr-0003-retrycontext-scene-reset.md)
**ADR Decision Summary**: HIT_STUN and DEAD are triggered by EventBus signals (`player_hp_changed` and `player_died`). DEAD exits ONLY via `reset_for_retry(ctx)` — no input or timer can exit it. The controller subscribes to EventBus signals in `_ready()` using Callable-based API.

**Governing ADRs**: ADR-0004 (primary — state machine transitions, knockback formula), ADR-0003 (secondary — DEAD exit contract, reset_for_retry ordering)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: EventBus signal subscription uses `EventBus.player_died.connect(_on_player_died)` Callable form (not deprecated string form). `player_hp_changed(current: float, max_hp: float)` — HP decrease detected by comparing `current < _prev_hp`.

**Control Manifest Rules (Core layer)**:
- Required: subscribe `player_died` and `player_hp_changed` via EventBus in `_ready()` using Callable API; DEAD exits only via `reset_for_retry()`; `_transition_to()` for all state changes
- Forbidden: string-based `connect("signal", obj, "method")`; any path out of DEAD other than `reset_for_retry()`
- Guardrail: `hit_stun_duration` must be ≤ 0.5s (player_hit_invuln_duration); enforce with a guard in `_ready()` or a clamping setter

---

## Acceptance Criteria

*From GDD `design/gdd/player-controller-system.md`, scoped to this story:*

- [ ] **AC-hit-stun-enter**: GIVEN player in any non-DEAD state, WHEN `player_hp_changed` signal received with `current < _prev_hp` (HP decreased), THEN state = HIT_STUN; `velocity.x = -facing_direction × knockback_speed`; `hit_stun_timer = hit_stun_duration`; input ignored during timer
- [ ] **AC-hit-stun-reset**: GIVEN player in HIT_STUN (`hit_stun_timer = 0.15`), WHEN `player_hp_changed` received again (HP decrease), THEN `hit_stun_timer` resets to `hit_stun_duration`; `velocity.x` updated with new `facing_direction × knockback_speed`
- [ ] **AC-hit-stun-exit**: GIVEN player in HIT_STUN, WHEN `hit_stun_timer` counts to ≤ 0.0, THEN state transitions to IDLE (or RUNNING if move input held)
- [ ] **AC-dead-enter**: GIVEN player in ANY state (IDLE/RUNNING/AIRBORNE/PARRYING/DODGING/HIT_STUN), WHEN `player_died` signal received, THEN state = DEAD; `velocity = Vector2.ZERO` same frame
- [ ] **AC-dead-priority**: GIVEN player in DODGING or PARRYING, WHEN `player_died` received, THEN DEAD entered immediately without waiting for `dodge_ended` or parry exit timer
- [ ] **AC-dead-input**: GIVEN player in DEAD state, WHEN any input action pressed, THEN no state change; `velocity` stays `Vector2.ZERO`; no signals emitted
- [ ] **AC-hit-stun-duration-constraint**: GIVEN `hit_stun_duration` @export var, WHEN value set > 0.5, THEN system warns/clamps to 0.5 (player_hit_invuln_duration max per GDD)

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0003 Implementation Guidelines:*

**EventBus subscription in `_ready()`** (Callable API, not string form):
```gdscript
func _ready() -> void:
    spawn_position = global_position
    EventBus.player_died.connect(_on_player_died)
    EventBus.player_hp_changed.connect(_on_player_hp_changed)
```

**`_on_player_died()` handler**:
```gdscript
func _on_player_died() -> void:
    _transition_to(GameEnums.PlayerState.DEAD)
```

**`_on_player_hp_changed(current: float, max_hp: float)` handler**:
```gdscript
func _on_player_hp_changed(current: float, max_hp: float) -> void:
    if current < _prev_hp:  # HP decreased → HIT_STUN
        if player_state != GameEnums.PlayerState.DEAD:
            _transition_to(GameEnums.PlayerState.HIT_STUN)
    _prev_hp = current
```

**`_enter_state(HIT_STUN)` behavior**:
```gdscript
GameEnums.PlayerState.HIT_STUN:
    hit_stun_timer = hit_stun_duration
    velocity.x = -facing_direction * knockback_speed
```

**`_enter_state(DEAD)` behavior**:
```gdscript
GameEnums.PlayerState.DEAD:
    velocity = Vector2.ZERO
```

**HIT_STUN → re-hit behavior** (re-entering HIT_STUN from HIT_STUN is valid):
Because `_transition_to(HIT_STUN)` always calls `_enter_state(HIT_STUN)`, the timer and velocity are simply reset. No special "re-hit" path needed — the standard transition handles it.

**`_process_state(delta)` — HIT_STUN branch**:
```gdscript
GameEnums.PlayerState.HIT_STUN:
    velocity.x = -facing_direction * knockback_speed   # lock velocity during stun
    hit_stun_timer -= delta
    if hit_stun_timer <= 0.0:
        _transition_to(GameEnums.PlayerState.IDLE)  # or RUNNING
```

**`_process_state(delta)` — DEAD branch**:
```gdscript
GameEnums.PlayerState.DEAD:
    velocity = Vector2.ZERO   # ensure velocity stays zero every frame
```

**`hit_stun_duration` constraint** — enforce in setter or `_ready()`:
```gdscript
@export var hit_stun_duration: float = 0.30:
    set(value):
        if value > 0.5:
            push_warning("hit_stun_duration %f exceeds player_hit_invuln_duration 0.5s; clamping." % value)
            hit_stun_duration = 0.5
        else:
            hit_stun_duration = value
```

**DEAD → all input disabled**: `_handle_input()` has DEAD guard at the top (`if player_state == DEAD: return`), which is Story 001's responsibility. This story verifies the guard is effective.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: DEAD guard in `_handle_input()` skeleton
- [Story 006]: `reset_for_retry(ctx)` — the DEAD exit path; this story only implements DEAD entry

---

## QA Test Cases

*Written at story creation. Developer implements against these — do not invent new cases during implementation.*

- **AC-hit-stun-enter**: HIT_STUN entered on HP decrease
  - Given: player_state = IDLE, facing_direction = 1, knockback_speed = 200.0, hit_stun_duration = 0.30
  - When: `_on_player_hp_changed(50.0, 100.0)` called (_prev_hp was 100.0)
  - Then: state = HIT_STUN; velocity.x = -200.0; hit_stun_timer = 0.30
  - Edge cases: HP increase (healing) → no HIT_STUN; HP unchanged → no HIT_STUN; DEAD state → no HIT_STUN (DEAD guard)

- **AC-hit-stun-reset**: Timer reset on re-hit during HIT_STUN
  - Given: player_state = HIT_STUN, hit_stun_timer = 0.15 (half elapsed), facing_direction = 1
  - When: `_on_player_hp_changed()` called with HP decrease (simulated second hit)
  - Then: hit_stun_timer = 0.30 (reset); velocity.x = -facing_direction × knockback_speed (overwritten)
  - Edge cases: velocity direction updates if facing changed (shouldn't change during HIT_STUN, but formula recalculates)

- **AC-hit-stun-exit**: Timer expiry transitions out of HIT_STUN
  - Given: player_state = HIT_STUN, hit_stun_timer = 0.01
  - When: `_process_state(0.02)` called (delta > remaining timer)
  - Then: state = IDLE (or RUNNING if move input); hit_stun_timer = 0
  - Edge cases: exact boundary (timer == delta) → transitions

- **AC-dead-enter**: player_died from any state → DEAD
  - Given: player_state = IDLE (repeat for RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN)
  - When: `_on_player_died()` called
  - Then: state = DEAD; velocity = Vector2.ZERO
  - Edge cases: player_died while already DEAD → no re-entry (guard handles it? or transition is idempotent)

- **AC-dead-priority**: DODGING/PARRYING interrupted by player_died
  - Given: player_state = DODGING
  - When: `_on_player_died()` called
  - Then: state = DEAD immediately; no waiting for `dodge_ended` signal
  - Edge cases: PARRYING → DEAD also works; `parry_exit_timer` is irrelevant once DEAD

- **AC-dead-input**: DEAD blocks all input
  - Given: player_state = DEAD
  - When: all 6 input actions just-pressed (move_left, move_right, jump, parry, dodge, attack)
  - Then: state stays DEAD; velocity stays Vector2.ZERO; no signals emitted
  - Edge cases: DEAD guard in `_handle_input()` is the first check — verify it's the FIRST line

- **AC-hit-stun-duration-constraint**: Duration clamped at 0.5
  - Given: hit_stun_duration @export var
  - When: set to 0.51
  - Then: actual value is clamped to 0.50; push_warning() called
  - Edge cases: 0.50 exactly is valid (equal to invuln duration); 0.0 → allow (degenerate but valid)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/player_controller/test_pc_hit_stun.gd` — must exist and pass

*Note: GUT requires `test_` prefix.*

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerController Skeleton) must be DONE
- Unlocks: Story 006 (reset_for_retry needs DEAD state to exist to verify exit path)

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 7/7 passing
**Deviations**: ADVISORY — `reset_for_retry(_ctx: Dictionary) -> void` skeleton stub added beyond story scope; resolves malformed Story 001 doc comment and skeletonises ADR-0003 contract; no logic implemented. Logged to tech-debt register.
**Test Evidence**: Integration test at `game/tests/integration/player_controller/test_pc_hit_stun.gd` — 21 tests, all passing (33/33 suite, 3 pre-existing pending from Story 003)
**Code Review**: Complete (/code-review APPROVED after specialist review + fixes)
