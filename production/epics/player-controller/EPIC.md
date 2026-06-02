# Epic: PlayerController

> **Layer**: Core
> **GDD**: design/gdd/player-controller-system.md
> **Architecture Module**: PlayerController (Core Layer — architecture.md)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories player-controller`

## Overview

PlayerController is the root of all player agency. It uses `CharacterBody2D` +
`move_and_slide()` to handle gravity and collision, translates raw InputMap
actions into a 7-state machine (IDLE / RUNNING / AIRBORNE / PARRYING / DODGING /
HIT_STUN / DEAD), and broadcasts state-change signals to downstream systems.
The controller does not decide whether a parry succeeded — it only emits
`parry_input_pressed` and waits for `exit_parry_state(duration)` in return. It
does not calculate dodge physics — it emits `dodge_input_pressed(direction)` and
pauses its own physics while DodgeSystem controls position. This strict
separation keeps the controller testable in isolation and ensures that "control
feels precise" is a verifiable quality — the controller's job is to convert
input into state instantly and faithfully, so all player attention can go to
reading Boss telegraphs.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Player State Machine Architecture | Enum-based state machine on CharacterBody2D; `_transition_to()` dispatcher; `_handle_input()` with priority-ordered early returns (DEAD → parry → dodge → jump → attack → move); all params @export var | LOW |
| ADR-0001: Signal Routing Architecture | PlayerController 1:1 signals (parry_input_pressed, attack_input_pressed, dodge_input_pressed) emitted as direct node signals — NOT via EventBus; single-consumer 1:1 exception established in ADR-0001 | LOW |
| ADR-0003: RetryContext and Scene Reset Strategy | PlayerController must implement reset_for_retry(ctx): reset player_state, velocity, position, facing_direction, all timers; retry grants 2.0s invuln | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PC-001 | Player uses CharacterBody2D processed via move_and_slide() each physics frame | ✅ ADR-0004 |
| TR-PC-002 | Complete 7-state machine: IDLE, RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN, DEAD | ✅ ADR-0004 |
| TR-PC-003 | 6 InputMap actions (move_left, move_right, jump, parry, dodge, attack); references action StringNames only, no hardcoded keycodes | ✅ ADR-0004 |
| TR-PC-004 | Same-frame parry + dodge: parry wins, dodge ignored (parry priority rule) | ✅ ADR-0004 |
| TR-PC-005 | Coyote time (0.10s) and jump buffer (0.12s) timers | ✅ ADR-0004 |
| TR-PC-006 | attack input emits attack_input_pressed only in IDLE/RUNNING/AIRBORNE; no state change, no movement lock; ignored in PARRYING/DODGING/HIT_STUN/DEAD | ✅ ADR-0004 |
| TR-PC-007 | Bidirectional parry contract: emits parry_input_pressed on PARRYING enter; receives exit_parry_state(duration) to leave PARRYING | ✅ ADR-0001 + ADR-0004 |
| TR-PC-008 | AIRBORNE gravity: velocity.y += gravity × delta, clamped to terminal_velocity; grounded sets velocity.y = 0 | ✅ ADR-0004 |
| TR-PC-009 | HIT_STUN: velocity.x = -facing_direction × knockback_speed for hit_stun_duration; hit_stun_duration ≤ player_hit_invuln_duration (0.5s) | ✅ ADR-0004 |
| TR-PC-010 | DEAD state entered on player_died from any state; exits ONLY via external retry reset signal; all input disabled | ✅ ADR-0003 + ADR-0004 |
| TR-PC-011 | All tuning parameters declared as @export var; no numeric literals (340, 1400, 600, 0.10, 0.12, 200, 0.30) in logic code | ✅ ADR-0004 |
| TR-PC-012 | Horizontal velocity is instant: velocity.x = dir × move_speed; snaps to 0 same frame on release; no acceleration curve or lerp | ✅ ADR-0004 |
| TR-PC-013 | dodge emits dodge_input_pressed(direction); controller pauses own physics while DodgeSystem controls position; resumes on dodge_ended | ✅ ADR-0001 + ADR-0004 |
| TR-PC-014 | Controller _physics_process logic under 0.5ms per frame | ✅ ADR-0004 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-controller-system.md` are verified
- All Logic stories have passing test files in `game/tests/unit/player_controller/`
- Performance budget confirmed: `_physics_process` < 0.5ms/frame (Godot Profiler)
- No numeric literals (340, 1400, 600, etc.) appear in any `.gd` logic file — all @export var
- All input references use StringName action names (`&"parry"`, `&"jump"`, etc.)
- `reset_for_retry(ctx)` implementation verified by integration test (retry flow)

## Next Step

Run `/create-stories player-controller` to break this epic into implementable stories.
