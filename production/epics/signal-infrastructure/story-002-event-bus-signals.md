# Story 002: EventBus Autoload — Typed Signal Declarations

> **Epic**: Signal Infrastructure
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: N/A — architectural infrastructure module (no owning GDD)
**Requirement**: N/A — infrastructure; no GDD TR-ID assigned
*(This story unblocks: TR-HDS-004, TR-HDS-005, TR-HDS-006, TR-HDS-013,
TR-PTS-001, TR-PTS-005, TR-PTS-007, TR-PTS-009, TR-CAC-007, TR-CAC-008,
TR-IRS-001, TR-IRS-011, TR-BSM-006, TR-BSM-012, TR-HUD-007)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture
**ADR Decision Summary**: All 1:N cross-module signals are declared on
`game/autoloads/event_bus.gd`, registered as Autoload "EventBus". Systems emit via
`EventBus.signal_name.emit()` and subscribe via `EventBus.signal_name.connect(callable)`.
PlayerController's 1:1 control signals are the sole exception — they stay on the
node itself and are NOT on EventBus.

**Secondary ADR**: ADR-0002: BossData Resource Architecture (GameEnums types used
in signal parameter declarations)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Callable-based signal API is stable since Godot 4.0; no
post-cutoff breaking changes in the signal subsystem. Autoload singleton access
(`EventBus.signal_name`) is the standard pattern. Verify Autoload is reachable
in GUT test context (covered by Story 003).

**Control Manifest Rules (Foundation layer)**:
- Required: All 1:N cross-module signals on `game/autoloads/event_bus.gd`; emit via `EventBus.signal_name.emit()`; subscribe via `EventBus.signal_name.connect(callable)`
- Required: Typed signals with parameter types — e.g. `signal player_hp_changed(current: float, max_hp: float)`
- Required: Autoload registration order — EventBus must be FIRST (before RetryContext and HitpauseManager)
- Required: Signal connections use Callable-based API only
- Forbidden: `connect("signal_name", obj, "method")` — deprecated string form
- Forbidden: 1:N broadcast signals defined on individual system nodes
- Guardrail: EventBus Autoload load time < 1ms at project startup

---

## Acceptance Criteria

*Derived from ADR-0001 Decision, Key Interfaces, Validation Criteria, and Epic DoD:*

- [ ] File `game/autoloads/event_bus.gd` exists, `extends Node`
- [ ] All 13 typed cross-module signals are declared, grouped by domain with comment separators:
  - Combat telegraph: `attack_telegraphed(attack_type: GameEnums.AttackType, damage: float)`, `parry_succeeded(attack_type: GameEnums.AttackType)`, `parry_failed(attack_type: GameEnums.AttackType)`, `stagger_ended()`, `counter_full_combo_completed(attack_type: GameEnums.AttackType)`
  - Player state: `player_died()`, `player_hp_changed(current: float, max_hp: float)`
  - Boss state: `boss_defeated()`, `boss_phase_changed(from_phase: int, to_phase: int)`, `boss_hp_changed(current: float, max_hp: float, phase: int)`
  - Per-frame stream: `telegraph_updated(progress: float, window_open: bool, attack_type: GameEnums.AttackType)`, `counter_window_updated(hit_count: int, time_remaining: float, state: GameEnums.ComboState)`
  - Retry: `retry_death_count_changed(count: int)`
- [ ] No signal is defined with untyped parameters for cross-module use
- [ ] EventBus is registered as Autoload named `"EventBus"` in Project Settings → Autoload, and is listed FIRST (before RetryContext and HitpauseManager)
- [ ] `grep 'connect("'` across all `.gd` files returns 0 results (no deprecated string-based connect)
- [ ] `grep 'emit("'` across all `.gd` files returns 0 results (no deprecated string-based emit)

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

The file must be `game/autoloads/event_bus.gd`. The Autoload name in Project Settings
must be exactly `"EventBus"` (capital E, capital B) — other systems reference it
by this name.

Signal parameter types reference `GameEnums.AttackType` and `GameEnums.ComboState`.
Story 001 (GameEnums) must be DONE and the editor restarted before this file can be
saved without parse errors.

Domain grouping with comment separators is required by ADR-0001 to keep the file
navigable. Use the exact groups shown in the Key Interfaces section of ADR-0001.

**Do not add** `parry_input_pressed`, `attack_input_pressed`, `dodge_input_pressed`,
or `exit_parry_state` to EventBus — these are PlayerController 1:1 node signals
(single consumer each). Adding them to EventBus would violate the ADR-0001 exception
rule and ADR-0004 constraints.

Autoload registration in Project Settings → Autoload:
1. `EventBus` → `res://autoloads/event_bus.gd`
2. `RetryContext` → (added when retry-context epic is implemented)
3. `HitpauseManager` → (added when hitpause epic is implemented)

Only #1 is set during this story. The ordering constraint applies when subsequent
Autoloads are added.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: GameEnums enum definitions (must be done first)
- [Story 003]: GUT test confirming EventBus reachability and mock injection
- [retry-context epic]: RetryContext Autoload registration
- [bossdata-resource-architecture epic]: BossDataLoader, BossData Resource files

---

## QA Test Cases

*Test cases not yet defined — run /qa-plan to generate them.*

**AC-1**: All 13 signals declared with correct names and parameter types
- Given: `game/autoloads/event_bus.gd` is parsed by Godot
- When: each signal name and parameter signature is inspected
- Then: all 13 signals are present; each parameter has an explicit type annotation; no signal is untyped
- Edge cases: missing signal → any story that depends on it will fail at connection time; wrong type → GDScript type error at emit

**AC-2**: Autoload registered as "EventBus" and is first in load order
- Given: Project Settings → Autoload panel is open
- When: the Autoload list is inspected
- Then: `EventBus` appears as the first entry, pointing to `res://autoloads/event_bus.gd`; accessing `EventBus` from any script returns the singleton
- Edge cases: wrong name → all `EventBus.signal_name` references become undefined at runtime; wrong order → systems that depend on EventBus being ready may initialize before it exists

**AC-3**: No deprecated string-based connect/emit usage in codebase
- Given: full project `.gd` source is on disk
- When: grep for `connect("` and `emit("` patterns across all `.gd` files
- Then: 0 matches (Callable-based API only)
- Edge cases: a single string-based connect is a code-review blocker

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `game/tests/unit/signal-infrastructure/test_event_bus.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 must be DONE (GameEnums class must be registered for typed signal parameters to parse)
- Unlocks: Story 003 (mock injection test requires EventBus to exist)

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 6/6 passing
**Deviations**: GUT addon `addons/gut/input_sender.gd` uses deprecated `connect("...")` — third-party code, outside project scope; AC-5 passes for our code.
**Test Evidence**: Logic — `game/tests/unit/signal-infrastructure/test_event_bus.gd` — 35/35 passing (combined with story-001 tests)
**Code Review**: Complete
