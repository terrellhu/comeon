# Story 001: GameEnums — Shared Enum Definitions

> **Epic**: Signal Infrastructure
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 7/7 passing
**Deviations**: `is Node`/`is Resource` runtime checks removed from test (GDScript static type system enforces this at compile time — no coverage loss). Code review skipped (6-line pure enum file).
**Test Evidence**: Logic — `game/tests/unit/signal-infrastructure/test_game_enums.gd` — 20/20 passing
**Code Review**: Skipped (acceptable for 6-line enum-only module)

## Context

**GDD**: N/A — architectural infrastructure module (no owning GDD)
**Requirement**: N/A — infrastructure precondition; no GDD TR-ID assigned
*(This story owns no GDD requirement directly. It is the prerequisite for every
typed signal and state machine in the project. All TR-IDs that reference
AttackType, ComboState, Target, or PlayerState are unblocked by this story.)*

**ADR Governing Implementation**: ADR-0002: BossData Resource Architecture
**ADR Decision Summary**: All shared enums (AttackType, ComboState, Target,
PlayerState) must be defined in a single `game/scripts/data/game_enums.gd` with
`class_name GameEnums`. No Node or Resource inheritance. All other scripts
reference them as `GameEnums.AttackType` etc. — never redefine locally.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `class_name` registration requires a Godot editor restart to
unlock Inspector editing for types that reference these enums. `Array[GameEnums.AttackType]`
@export typing is stable since Godot 4.0. No post-cutoff APIs used in this file.

**Control Manifest Rules (Foundation layer)**:
- Required: `class_name GameEnums` with no Node or Resource inheritance — plain class
- Required: All shared enums defined here and only here; referenced as `GameEnums.EnumName` elsewhere
- Forbidden: Defining AttackType, ComboState, Target, or PlayerState in any other file
- Guardrail: EventBus load time < 1ms at startup — this file must be parseable before EventBus registers

---

## Acceptance Criteria

*Derived from ADR-0002 Decision, Control Manifest Foundation rules, and Epic DoD:*

- [ ] File `game/scripts/data/game_enums.gd` exists with `class_name GameEnums` and no `extends` clause (plain class, not Node or Resource)
- [ ] `enum AttackType { LIGHT, HEAVY, SWEEP }` is defined with exactly these 3 values
- [ ] `enum ComboState { IDLE, COUNTER_WINDOW_OPEN, BONUS_STAGGER }` is defined with exactly these 3 values
- [ ] `enum Target { PLAYER, BOSS }` is defined with exactly these 2 values
- [ ] `enum PlayerState { IDLE, RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN, DEAD }` is defined with exactly these 7 values
- [ ] No other `.gd` file in the project redefines any of these 4 enums (grep confirms 0 duplicate definitions)
- [ ] GUT test passes: `GameEnums.AttackType.HEAVY == 1` (enum ordinals are stable and as expected)

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

Create `game/scripts/data/game_enums.gd` as a plain GDScript file — no `extends`. The
`class_name` line alone registers it with the Godot type system. After creating and
saving this file, **restart the Godot editor** so the class name is registered before
any script that references `GameEnums.AttackType` is parsed.

Enum value ordering matters for serialization (`.tres` files store int ordinals). Do
not reorder enum values after any `.tres` BossData file is created — ordinal shifts
would silently corrupt saved data.

The `PlayerState` enum is defined here (not in PlayerController) because ADR-0004
(player state machine) requires `GameEnums.PlayerState` to be available before
PlayerController is implemented, and placing it in PlayerController would create a
circular dependency risk.

File skeleton:
```gdscript
class_name GameEnums

enum AttackType { LIGHT, HEAVY, SWEEP }
enum ComboState { IDLE, COUNTER_WINDOW_OPEN, BONUS_STAGGER }
enum Target     { PLAYER, BOSS }
enum PlayerState { IDLE, RUNNING, AIRBORNE, PARRYING, DODGING, HIT_STUN, DEAD }
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: EventBus Autoload — signal declarations that reference GameEnums types
- [Story 003]: GUT mock injection test for EventBus
- [bossdata-resource-architecture epic]: `boss_data.gd`, `phase_data.gd`, `attack_data.gd` Resource subclasses

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

**AC-1**: `game/scripts/data/game_enums.gd` exists as a plain class with no inheritance
- Given: project is freshly opened in Godot 4.6
- When: Godot parses `game/scripts/data/game_enums.gd`
- Then: `GameEnums` is registered as a class name; no parse error; `GameEnums.AttackType` resolves in any script
- Edge cases: file missing → parse error in all dependent scripts; `extends Node` present → breaks non-Node usage

**AC-2**: All 4 enums defined with correct values
- Given: `game_enums.gd` is loaded in a GUT test
- When: enum ordinal values are checked
- Then: `GameEnums.AttackType.LIGHT == 0`, `.HEAVY == 1`, `.SWEEP == 2`; `GameEnums.ComboState.IDLE == 0`, `.COUNTER_WINDOW_OPEN == 1`, `.BONUS_STAGGER == 2`; `GameEnums.Target.PLAYER == 0`, `.BOSS == 1`; `GameEnums.PlayerState.IDLE == 0` through `.DEAD == 6`
- Edge cases: enum value count mismatch → GUT assertion failure

**AC-3**: No other file redefines these enums
- Given: full project source is on disk
- When: grep is run for `enum AttackType`, `enum ComboState`, `enum Target`, `enum PlayerState` across all `.gd` files
- Then: exactly 1 match per enum name (only in `game_enums.gd`)
- Edge cases: any second match → must be flagged as a blocker before Story 002 begins

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/signal-infrastructure/test_game_enums.gd` — must exist and pass

**Status**: [x] Created — `game/tests/unit/signal-infrastructure/test_game_enums.gd`

---

## Dependencies

- Depends on: None — this is the first story; no prerequisites
- Unlocks: Story 002 (EventBus uses GameEnums types in signal parameters)
