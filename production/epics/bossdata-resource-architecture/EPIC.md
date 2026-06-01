# Epic: BossData Resource Architecture

> **Layer**: Foundation
> **GDD**: design/gdd/boss-state-machine.md (primary); health-damage-system.md, parry-telegraph-system.md, instant-retry-system.md (consumers)
> **Architecture Module**: BossDataLoader + BossData/PhaseData/AttackData Resource classes (architecture.md Foundation Layer)
> **Manifest Version**: 2026-06-01
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories bossdata-resource-architecture`

## Overview

This epic builds the data layer that drives every Boss-specific value in the game.
It defines the three-level GDScript Resource hierarchy (BossData → PhaseData[] →
AttackData[]) stored as `.tres` files, plus the `BossDataLoader` node that loads
and validates them. The GDD mandate "no gameplay literals in .gd files" is enforced
here: HP pools, phase thresholds, attack sequences, damage values, telegraph
overrides, and the death-screen phase symbol all live in data, not code. Three
Core/Feature systems (BossStateMachine, HealthDamageSystem, ParryTelegraphSystem)
cannot be implemented until this structure exists.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: BossData Resource Architecture | Three-level Resource subclasses (.tres) over JSON; BossDataLoader validates on load; GameEnums shared | MEDIUM (`duplicate_deep()` Godot 4.5 post-cutoff — not needed for single-Boss MVP; `Array[ResourceType]` @export stable since 4.0) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-HDS-010 | boss_max_hp + phase_threshold_pct[] from BossData, not hardcoded | ADR-0002 ✅ |
| TR-BSM-002 | BossData Resource drives all Boss-specific data | ADR-0002 ✅ |
| TR-BSM-003 | telegraph_duration_override = 0 uses AttackType default | ADR-0002 ✅ |
| TR-BSM-009 | Load-time validation (empty seq error / invalid override clamp / missing anim graceful) | ADR-0002 ✅ |
| TR-BSM-010 | No BossData literals in .gd; values via @export read | ADR-0002 ✅ |
| TR-PTS-011 | All parry timing values injected, per-Boss override permitted | ADR-0002 ⚠️ partial |
| TR-IRS-002 | Death-screen phase_symbol from BossData (PhaseData.phase_symbol) | ADR-0002 ✅ |

**Untraced Requirements**: TR-PTS-011 (partial) — `window_open_fraction`, `window_width`,
`stagger_duration` per-Boss overrides are NOT in the AttackData schema. Control Manifest
Open Items sets the default: these live as `@export var` on ParryTelegraphSystem until a
design decision adds them to the Resource schema. Stories for TR-PTS-011 reference the
manifest default — **not blocked**.

## Scope

- `scripts/data/attack_data.gd` — `class_name AttackData extends Resource`
- `scripts/data/phase_data.gd` — `class_name PhaseData extends Resource` (incl. `phase_symbol: Texture2D`)
- `scripts/data/boss_data.gd` — `class_name BossData extends Resource`
- `scripts/foundation/boss_data_loader.gd` — `get_boss_data()` + `_validate()`
- `res://data/bosses/boss_01.tres` — first MVP Boss data asset
- GUT test using `BossData.new()` factory (no .tres file I/O)

## Definition of Done

This epic is complete when:
- All three Resource classes are `class_name`-registered and Inspector-editable
- BossDataLoader `_validate()` enforces: empty attack_sequence → error/refuse load;
  invalid telegraph override → clamp 0.1s + warning; descending phase_threshold_pct
- Empty `attack_sequence` triggers assert; battle does not start
- GUT test creates data via factory and runs without file I/O
- `grep` confirms no BossData literals (1000.0, 0.8, 1.2, 1.5) in BossStateMachine code
- All stories implemented, reviewed, and closed via `/story-done`

## Next Step

Run `/create-stories bossdata-resource-architecture` to break this epic into implementable stories.
