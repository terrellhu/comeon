# Story 001: HP Initialization and BossData Contract

> **Epic**: HealthDamageSystem
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage-system.md`
**Requirements**: `TR-HDS-001`, `TR-HDS-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: BossData Resource Architecture (primary); ADR-0001: Signal Routing Architecture (secondary)
**ADR Decision Summary**: Boss-specific values (`boss_max_hp`, `phase_threshold_pct[]`) come from GDScript Resource subclass `.tres` files via BossDataLoader. No numeric literals in logic code. Systems accept optional EventBus injection via `initialize(event_bus)` for GUT testability.

**Engine**: Godot 4.6 | **Risk**: LOW (Resource.new(), @export, ResourceLoader.load() — all stable since 4.0)
**Engine Notes**: Confirm `Array[PhaseData]` @export resolves correctly in Godot Inspector with nested .tres. No post-cutoff APIs involved.

**Control Manifest Rules (Core Layer)**:
- Required: `HealthDamageSystem is the sole owner of HP mutation` — only `apply_damage` and `apply_healing` write HP fields
- Required: `All systems must accept optional EventBus injection` via `initialize(event_bus: EventBus = null)`
- Forbidden: `Never let any module other than HealthDamageSystem write HP fields directly`
- Forbidden: No gameplay literals (100, 1000, 0.5, etc.) in `.gd` logic files

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage-system.md`, scoped to this story:*

- [x] **GIVEN** new battle start, default config, **WHEN** system initializes, **THEN** `current_player_hp` equals `player_max_hp` (e.g. 100.0), and HUD segment count equals `player_hp_segments` (e.g. 5)
- [x] **GIVEN** `boss_max_hp = 1000.0` defined in a BossData `.tres` asset, **WHEN** system initializes from that asset, **THEN** `current_boss_hp` equals the asset value (not a hardcoded literal)
- [x] **GIVEN** the GDD-specified base values (`player_max_hp = 100`, `player_hp_segments = 5`, etc.), **WHEN** the source file is inspected, **THEN** these numbers do NOT appear as float/int literals in any `.gd` logic file — all values loaded from `@export var` or BossData

---

## Implementation Notes

*Derived from ADR-0002 and ADR-0001 Implementation Guidelines:*

- Declare all player-side parameters as `@export var`:
  ```gdscript
  @export var player_max_hp: float = 100.0
  @export var player_hp_segments: int = 5
  @export var player_hit_invuln_duration: float = 0.5
  ```
- Boss HP is read from `BossDataLoader.get_boss_data(boss_id)` in `_ready()`. Store the result; do not call `ResourceLoader.load()` again during combat.
- Provide `initialize(event_bus: EventBus = null)` — in tests, pass a mock; in production, omit.
- `current_player_hp` and `current_boss_hp` must be initialized in `_ready()` or an explicit `init_battle(boss_data: BossData)` method — not at declaration time, so BossData can be injected in tests via `BossData.new()`.
- Follow the `_make_test_boss()` factory pattern (ADR-0002) in test fixtures — do not read `.tres` files from tests.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `apply_damage(PLAYER, ...)` logic and INVULNERABLE state
- Story 005: Boss HP damage and phase detection

---

## QA Test Cases

**Test file**: `game/tests/unit/health_damage/test_hp_initialization.gd` — 11/11 PASS (2026-06-02)

**GDD formula**: HDS init contract — `current_player_hp == player_max_hp`, `current_boss_hp == boss_data.boss_max_hp`

- **HP init from BossData**: `init_battle(boss_data)` → `current_player_hp = player_max_hp (100.0)`, `current_boss_hp = boss_data.boss_max_hp (1000.0)` — no hardcoded literals
- **Non-standard boss HP**: `boss_data.boss_max_hp = 500.0` → `current_boss_hp = 500.0`
- **No literals in logic**: grep `game/scripts/core/health_damage_system.gd` for `100`, `1000` — 0 matches in logic code
- **hp_per_segment formula**: `hp_per_segment = player_max_hp / player_hp_segments` (100 / 5 = 20.0)
- **Edge cases**: `init_battle` with null boss_data → assert or graceful guard (boundary behaviour documented in GDD Edge Cases)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/health_damage/test_hp_initialization.gd` — must exist and pass

> **GUT naming rule**: file must be named `test_hp_initialization.gd` (prefix `test_`).
> Do NOT use class_name type annotations on the test class in headless mode — declare as `extends GutTest` without `class_name`.

**Status**: [x] `game/tests/unit/health_damage/test_hp_initialization.gd` — 11/11 PASS (2026-06-02)

---

## Dependencies

- Depends on: Foundation layer epics — `signal-infrastructure` (EventBus) and `bossdata-resource-architecture` (BossData, BossDataLoader) must be DONE
- Unlocks: Story 002 (player damage), Story 005 (boss HP)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 3/3 passing
**Deviations**: None — `get_displayed_segments()` deferred to Story 006 per stated scope; `_boss_data` field pre-declared for Stories 002–005
**Test Evidence**: Logic — `game/tests/unit/health_damage/test_hp_initialization.gd` — 11/11 PASS
**Code Review**: Complete — APPROVED after 4 fixes (as Node cast, _ready() guard, MockEventBus injection in before_each, removed redundant after_each)
