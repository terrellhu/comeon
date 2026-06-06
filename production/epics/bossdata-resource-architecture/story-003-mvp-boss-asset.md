# Story 003: MVP Boss Data Asset + GUT Factory Proof

> **Epic**: BossData Resource Architecture
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/boss-state-machine.md`
**Requirement**: TR-BSM-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: BossData Resource Architecture
**ADR Decision Summary**: All Boss-specific values (HP, phases, attack sequences, damage, telegraph overrides) live in `.tres` Resource files under `res://data/bosses/`, not in any `.gd` file. GUT tests create BossData instances in code via `BossData.new()` — never by loading `.tres` files — so tests run headlessly without project file I/O.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Creating `.tres` files requires the Godot editor with `class_name` types registered. `.tres` is a text format suitable for Git diff. ResourceLoader.load() resolves nested sub-resources (PhaseData, AttackData embedded in the .tres). The `.tres` file must be created via the editor Inspector — it cannot be reliably created headlessly.

**Control Manifest Rules (Foundation layer)**:
- Required: GUT tests must inject BossData via `BossData.new()` in code — never depend on `.tres` file I/O
- Required: Provide a `_make_test_boss()` factory helper in each test class
- Forbidden: Never use JSON + Dictionary for BossData
- Guardrail: ResourceLoader.load() called once at battle start, cached — never called during GUT tests

---

## Acceptance Criteria

*From TR-BSM-010, ADR-0002 validation criteria, and Epic Definition of Done:*

- [ ] `game/data/bosses/boss_01.tres` exists as a valid Godot `.tres` file with at least: 2 phases, each with ≥ 1 attack in attack_sequence; `boss_max_hp > 0`; `phase_threshold_pct` descending; `boss_id = &"boss_01"`
- [ ] BossDataLoader.get_boss_data(&"boss_01") loads `boss_01.tres` without assert or warning (validates successfully)
- [ ] GUT factory test creates a valid BossData instance entirely in code (no .tres file loaded) and passes BossDataLoader._validate() without errors
- [ ] GUT factory test's `_make_test_boss()` returns a BossData with: boss_id=&"test_boss", boss_max_hp=100.0, 1 phase, 1 AttackData (LIGHT, damage=10.0, override=0.0)
- [ ] `grep` for literals `0.8`, `1.2`, `1.5`, `1000.0`, `0.6`, `0.3` in `game/scripts/` returns 0 results (all such values live in .tres or in @export defaults, not in logic code)

---

## Implementation Notes

*Derived from ADR-0002 Migration Plan and Validation Criteria:*

### Creating boss_01.tres (requires Godot editor)

1. Open the Godot editor with `game/` as the project
2. FileSystem → Right-click `data/bosses/` → New Resource → select BossData
3. Set fields in Inspector:
   - `boss_id`: `boss_01`
   - `boss_max_hp`: 1000.0
   - `phase_threshold_pct`: [0.6, 0.3]
   - `phases`: add 2 PhaseData entries
     - Phase 0: `phase_index=0`, `idle_duration_after_attack=0.5`, add 3 AttackData entries
       - AttackData[0]: LIGHT, damage=15.0, override=0.0
       - AttackData[1]: HEAVY, damage=25.0, override=0.0
       - AttackData[2]: SWEEP, damage=20.0, override=0.0
     - Phase 1: `phase_index=1`, `idle_duration_after_attack=0.4`, add 3 AttackData entries
       - AttackData[0]: HEAVY, damage=30.0, override=1.0
       - AttackData[1]: SWEEP, damage=25.0, override=0.0
       - AttackData[2]: LIGHT, damage=15.0, override=0.5
4. Save as `res://data/bosses/boss_01.tres`
5. Verify in BossDataLoader.get_boss_data(&"boss_01") — should load cleanly

### GUT factory test

The factory test proves three things:
1. `BossData.new()` pattern works in headless GUT (no editor needed)
2. `_make_test_boss()` helper creates a valid BossData structure
3. The structure passes BossDataLoader._validate() without assertions

```gdscript
# game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd
extends GutTest

const BossData = preload("res://scripts/data/boss_data.gd")
const PhaseData = preload("res://scripts/data/phase_data.gd")
const AttackData = preload("res://scripts/data/attack_data.gd")
const BossDataLoader = preload("res://scripts/foundation/boss_data_loader.gd")

var _loader: Node

func before_each() -> void:
    _loader = BossDataLoader.new()
    add_child(_loader)

func after_each() -> void:
    _loader.queue_free()

func _make_test_boss() -> BossData:
    var attack := AttackData.new()
    attack.attack_type = GameEnums.AttackType.LIGHT
    attack.damage = 10.0
    attack.telegraph_duration_override = 0.0

    var phase := PhaseData.new()
    phase.phase_index = 0
    phase.attack_sequence = [attack]
    phase.idle_duration_after_attack = 0.5

    var boss := BossData.new()
    boss.boss_id = &"test_boss"
    boss.boss_max_hp = 100.0
    boss.phase_threshold_pct = [0.5]
    boss.phases = [phase]
    return boss
```

**GUT test consideration**: Use `preload()` for all resource types (headless class_name rule). GameEnums is accessible as a global class_name because it was registered via signal-infrastructure Story 001 — but in headless mode you may also need `const GameEnums = preload("res://scripts/data/game_enums.gd")`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Resource class definitions — must be DONE before .tres can be created
- [Story 002]: BossDataLoader._validate() logic — must be DONE before boss_01.tres can be verified

---

## QA Test Cases

**Test file**: `game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd` — 6/6 PASS (2026-06-02)

**Manual spot-check**: Open `game/data/bosses/boss_01.tres` in Godot inspector and confirm `boss_max_hp=1000`, `phase_threshold_pct=[0.6, 0.3]`, `phases.size()=2`.

**AC-1**: `_make_test_boss()` factory creates valid BossData in code
- Given: GUT test file with `_make_test_boss()` helper
- When: `_make_test_boss()` is called
- Then: returns non-null BossData; `boss.boss_id == &"test_boss"`; `boss.boss_max_hp == 100.0`; `boss.phases.size() == 1`; `boss.phases[0].attack_sequence.size() == 1`

**AC-2**: Factory data passes BossDataLoader._validate() without errors
- Given: `_make_test_boss()` result
- When: `_loader._validate(boss)` called
- Then: no assert fires; no warning emitted

**AC-3**: boss_01.tres loads and validates successfully
- Given: `boss_01.tres` exists in `game/data/bosses/`
- When: `_loader.get_boss_data(&"boss_01")` called
- Then: returns non-null BossData; `data.phases.size() == 2`; `data.boss_max_hp > 0`
- Edge cases: file missing → assert fires with path in message

**AC-4**: No gameplay literals in scripts/
- Given: full `game/scripts/` source tree
- When: `grep` for `0.8|1.2|1.5|1000\.0` across `*.gd` files
- Then: 0 matches in logic files (only permitted in @export default values and .tres content)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 AND Story 002 must both be DONE (Resource classes + loader validation must exist before .tres asset can be created and verified)
- Unlocks: All Core and Feature epics that read BossData (BossStateMachine, HealthDamageSystem, ParryTelegraphSystem, InstantRetrySystem)

---

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 5/5 passing
**Deviations**:
- ADVISORY: AC-2 load path verified via Godot headless script (not GUT unit test) — control manifest forbids .tres I/O in GUT; headless script is the correct alternative evidence path
- ADVISORY: AC-5 grep hits one @export default value (boss_max_hp in boss_data.gd:5) — explicitly permitted per QA test case spec
**Test Evidence**: Logic — game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd — 6/6 pass; AC-1/AC-2 additionally verified by Godot headless script
**Code Review**: Complete — CHANGES REQUIRED resolved (falsifiable assert added, phase_threshold_pct [0.5]→[0.6,0.3], two function renames)
