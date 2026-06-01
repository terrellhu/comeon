# Epic: Signal Infrastructure

> **Layer**: Foundation
> **GDD**: N/A (architectural infrastructure — not a GDD system)
> **Architecture Module**: EventBus Autoload + GameEnums (architecture.md Foundation Layer)
> **Manifest Version**: 2026-06-01
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories signal-infrastructure`

## Overview

This epic establishes the signal-routing backbone for the entire game. It creates
the `EventBus` Autoload that hosts all 1:N cross-module typed signals, and the
shared `GameEnums` file (AttackType, ComboState, Target, PlayerState) that every
other system references. No gameplay system can be implemented until this
infrastructure exists — every cross-module communication path defined in the 7 MVP
GDDs routes through these two files. This is the first thing built and the first
thing tested.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Signal Routing Architecture | EventBus Autoload for all 1:N signals; 1:1 controller signals stay direct on PlayerController | LOW |
| ADR-0002: BossData Resource Architecture | GameEnums defined in a single `game_enums.gd` with no Node/Resource dependency | MEDIUM |

## GDD Requirements

This module is signal-routing infrastructure — it owns no GDD requirements directly,
but it is the precondition for every signal-bearing TR across all systems. It
unblocks (does not by itself satisfy):

| Enables TR-IDs | Source System |
|----------------|---------------|
| TR-HDS-004, TR-HDS-005, TR-HDS-006, TR-HDS-013 | health-damage-system |
| TR-PTS-001, TR-PTS-005, TR-PTS-007, TR-PTS-009 | parry-telegraph-system |
| TR-CAC-007, TR-CAC-008 | counter-attack-combo |
| TR-IRS-001, TR-IRS-011 | instant-retry-system |
| TR-BSM-006, TR-BSM-012 | boss-state-machine |
| TR-HUD-007 | hud-system |

**Untraced Requirements**: None (infrastructure module — owns no GDD TR).

## Scope

- `autoloads/event_bus.gd` — 13 typed signals grouped by domain (combat telegraph,
  player state, boss state, per-frame stream, retry). Registered as Autoload `EventBus`.
- `scripts/data/game_enums.gd` — `class_name GameEnums` with AttackType, ComboState,
  Target, PlayerState enums. No Node/Resource inheritance.
- GUT test confirming EventBus is reachable in test context and mock injection works.

## Definition of Done

This epic is complete when:
- `event_bus.gd` defines all GDD-required signals with typed parameters (no missing, no duplicate)
- `game_enums.gd` defines all 4 shared enums and is referenced (not redefined) elsewhere
- No `connect("string", obj, "method")` usage anywhere (Callable-based only)
- GUT test confirms `initialize(mock_bus)` injection pattern works
- All stories implemented, reviewed, and closed via `/story-done`

## Next Step

Run `/create-stories signal-infrastructure` to break this epic into implementable stories.
