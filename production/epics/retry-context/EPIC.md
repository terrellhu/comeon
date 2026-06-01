# Epic: Retry Context & Hitpause Infrastructure

> **Layer**: Foundation
> **GDD**: design/gdd/instant-retry-system.md (primary); health-damage-system.md, boss-state-machine.md (reset_for_retry consumers)
> **Architecture Module**: RetryContext Autoload + HitpauseManager Autoload (architecture.md Foundation Layer)
> **Manifest Version**: 2026-06-01
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories retry-context`

## Overview

This epic builds the two time-and-state Autoloads that the combat loop depends on:
`RetryContext` (cross-reset persistence of Boss HP, Boss phase, and session death
count) and `HitpauseManager` (the `Engine.time_scale = 0` impact-freeze used across
all combat feel moments). It also defines the `reset_for_retry(ctx)` interface
contract that every resettable system implements — the contract lives here; each
system's concrete implementation ships in that system's own epic. These two
Autoloads must be registered before any Core or Feature combat system runs.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: RetryContext + Scene Reset | RetryContext Autoload + in-place reset (<100ms) over scene reload; ordered reset_for_retry chain | LOW (SceneTree.paused, process_mode stable since 4.0) |
| ADR-0005: Animation to Code Boundary | HitpauseManager Autoload via Engine.time_scale=0 + real-time timer; re-entrancy guard | LOW (Engine.time_scale + `create_timer(d,true,false,true)` — flagged for runtime verification) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-IRS-003 | Game logic time paused during death screen | ADR-0003 ✅ |
| TR-IRS-005 | RetryContext saves preserved_boss_hp, preserved_boss_phase, session_death_count | ADR-0003 ✅ |
| TR-IRS-006 | Scene reset completes within 1.5s window (in-place reset) | ADR-0003 ✅ |
| TR-IRS-010 | boss_defeated clears preserved_boss_hp | ADR-0003 ✅ |
| TR-IRS-011 | session_death_count++ + retry_death_count_changed signal | ADR-0003 ✅ |

**Untraced Requirements**: None.

> Note: the hitpause feel moments themselves (player hit 60ms, parry 60ms, 3rd hit
> 80ms, full combo 30ms) are consumed by combat systems in their own epics. This
> epic delivers the `HitpauseManager.trigger_hitpause()` mechanism only.

## Scope

- `autoloads/retry_context.gd` — `class_name RetryContextNode`: save/load/clear/is_fresh_start
- `autoloads/hitpause_manager.gd` — `class_name HitpauseManagerNode`: trigger_hitpause() with `_active` re-entrancy guard
- `reset_for_retry(ctx: Dictionary)` interface contract definition (documented; per-system implementations live in their own epics)
- Runtime verification: confirm `create_timer(d, true, false, true)` counts in real time while `Engine.time_scale = 0`
- GUT test: save→load round-trip; clear on boss_defeated; hitpause restores time_scale to 1.0

## Definition of Done

This epic is complete when:
- RetryContext + HitpauseManager registered as Autoloads in Project Settings
- RetryContext survives an in-place reset and returns correct preserved values
- `is_fresh_start()` correctly distinguishes new fight from retry
- HitpauseManager restores `Engine.time_scale = 1.0` after duration; re-entrancy guard prevents nesting
- Runtime verification of the time_scale+real-timer interaction passes on target hardware
- All stories implemented, reviewed, and closed via `/story-done`

## Next Step

Run `/create-stories retry-context` to break this epic into implementable stories.
