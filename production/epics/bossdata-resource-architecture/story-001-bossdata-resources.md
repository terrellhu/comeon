# Story 001: BossData Resource Class Hierarchy

> **Epic**: BossData Resource Architecture
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirement**: TR-BSM-002, TR-BSM-003, TR-HDS-010, TR-PTS-011, TR-IRS-002
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: BossData Resource Architecture
**ADR Decision Summary**: Three-level GDScript Resource subclasses (BossData → PhaseData[] → AttackData[]), all `class_name`-registered, stored as `.tres` text files. No JSON, no Dictionary — type-safe @export fields only. All shared enums in `GameEnums` (game_enums.gd, Story 001 of signal-infrastructure epic).

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Array[AttackData]` and `Array[PhaseData]` @export typing stable since Godot 4.0. `class_name` registration requires editor restart before `.tres` files can be saved with nested sub-resources. `duplicate_deep()` (Godot 4.5 post-cutoff) is NOT needed for single-Boss MVP — do not use it. Verify `Array[ResourceType]` @export renders correctly in Inspector before creating .tres assets.

**Control Manifest Rules (Foundation layer)**:
- Required: `BossData`, `PhaseData`, `AttackData` must be `class_name` GDScript Resource subclasses with `@export` fields; store as `.tres` text files under `res://data/bosses/`
- Required: All shared enums (AttackType, Target) referenced as `GameEnums.AttackType` etc. — never redefined locally
- Forbidden: JSON + Dictionary for BossData
- Forbidden: Defining AttackType or other shared enums in any of these files

---

## Acceptance Criteria

*From ADR-0002 Decision and TR-IDs TR-BSM-002, TR-BSM-003, TR-HDS-010, TR-PTS-011, TR-IRS-002:*

- [ ] `game/scripts/data/attack_data.gd` exists with `class_name AttackData extends Resource`, @export fields: `attack_type: GameEnums.AttackType`, `damage: float`, `telegraph_duration_override: float` (default 0.0, range 0.0–5.0)
- [ ] `game/scripts/data/phase_data.gd` exists with `class_name PhaseData extends Resource`, @export fields: `phase_index: int`, `attack_sequence: Array[AttackData]`, `idle_duration_after_attack: float` (default 0.5), `phase_transition_anim: StringName`, `phase_symbol: Texture2D`
- [ ] `game/scripts/data/boss_data.gd` exists with `class_name BossData extends Resource`, @export fields: `boss_id: StringName`, `boss_max_hp: float` (default 1000.0, range 1.0–10000.0), `phase_threshold_pct: Array[float]` (default [0.6, 0.3]), `phases: Array[PhaseData]`
- [ ] All three class names (`AttackData`, `PhaseData`, `BossData`) are recognized by GUT tests when preloaded via `preload("res://scripts/data/[file].gd")`
- [ ] No numeric literal (1000.0, 0.6, 0.3, 0.8, 1.2, 1.5 etc.) appears in any of the three .gd logic files beyond the `@export_range` decorator or default value declarations

---

## Implementation Notes

*Derived from ADR-0002 Key Interfaces:*

Create the three files in dependency order: `attack_data.gd` first (no dependencies), then `phase_data.gd` (depends on AttackData), then `boss_data.gd` (depends on PhaseData).

After creating `attack_data.gd`, **restart the Godot editor** so `AttackData` is registered as a class name before `phase_data.gd` uses it in `Array[AttackData]`. Same after `phase_data.gd` before `boss_data.gd`.

Use `@export_range` for range constraints:
```gdscript
@export_range(0.0, 5.0) var telegraph_duration_override: float = 0.0
@export_range(1.0, 10000.0) var boss_max_hp: float = 1000.0
```

`phase_transition_anim` should be `StringName` (not `String`) to match the ADR-0005 pattern where animation names are stored as StringName constants. Default: `&""`.

`phase_symbol: Texture2D` is used by InstantRetrySystem for the death-screen phase symbol. Leave `null` as default — BossDataLoader validation will warn (not assert) if missing.

Do not add any functions to these files — they are pure data containers. BossDataLoader (Story 002) owns all validation logic.

**GUT test consideration**: `class_name` is NOT auto-registered in headless GUT runs. In test files, use:
```gdscript
const AttackData = preload("res://scripts/data/attack_data.gd")
const PhaseData = preload("res://scripts/data/phase_data.gd")
const BossData = preload("res://scripts/data/boss_data.gd")
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 002]: BossDataLoader.get_boss_data() and _validate() — all validation logic goes there
- [Story 003]: Creating boss_01.tres data asset; GUT factory pattern proof test
- [signal-infrastructure epic Story 001]: GameEnums already complete — do not redefine AttackType here

---

## QA Test Cases

**Test file**: `game/tests/unit/bossdata-resource-architecture/test_bossdata_resources.gd` — 15/15 PASS (2026-06-02)

**AC-1**: AttackData has correct @export fields
- Given: `preload("res://scripts/data/attack_data.gd")` in GUT
- When: instance created via `.new()`
- Then: instance has properties `attack_type` (int/enum), `damage` (float = 10.0 default), `telegraph_duration_override` (float = 0.0 default)
- Edge cases: missing field → GUT property access returns null or causes error

**AC-2**: PhaseData has correct @export fields including Array[AttackData]
- Given: `preload` of phase_data.gd
- When: `phase.attack_sequence = [AttackData.new()]`
- Then: array accepts AttackData instances; `phase.idle_duration_after_attack` defaults to 0.5; `phase.phase_symbol` is null by default

**AC-3**: BossData has correct @export fields including Array[PhaseData]
- Given: `preload` of boss_data.gd
- When: instance created
- Then: `boss.boss_max_hp` defaults to 1000.0; `boss.phase_threshold_pct` defaults to [0.6, 0.3]; `boss.phases` is empty Array[PhaseData]

**AC-4**: All three types preload-accessible in headless GUT
- Given: test file uses `const AttackData = preload("res://scripts/data/attack_data.gd")`
- When: `AttackData.new()` called
- Then: non-null instance returned; no parse error

**AC-5**: No gameplay literals in .gd files
- Given: grep for `0.8`, `1.2`, `1.5`, `1000.0` across scripts/data/*.gd
- When: grep runs across the three files
- Then: 0 matches (only default values in @export declarations, not hardcoded logic)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/bossdata-resource-architecture/test_bossdata_resources.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: signal-infrastructure/story-001-game-enums.md must be DONE (GameEnums.AttackType used in AttackData @export)
- Unlocks: Story 002 (BossDataLoader validates BossData instances)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 5/5 passing
**Deviations**:
- New `class_name` scripts required a class-cache regen (`--headless --editor --quit --path game`) before headless GUT could resolve `AttackData`/`PhaseData`/`BossData`. This is a project-wide CI requirement — the test pipeline must run an editor import pass before GUT whenever new class_name scripts are added. Captured in memory `feedback-gut-file-naming`.
- Code review skipped (pure-data Resource classes, no logic).
**Test Evidence**: Logic — `game/tests/unit/bossdata-resource-architecture/test_bossdata_resources.gd` — 15/15 passing (full suite 55/55)
**Code Review**: Skipped
