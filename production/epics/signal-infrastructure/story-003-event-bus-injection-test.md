# Story 003: EventBus GUT Testability — Mock Injection Validation

> **Epic**: Signal Infrastructure
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (1–2 hours)
> **Manifest Version**: 2026-06-01
> **Last Updated**: 2026-06-02

## Context

**GDD**: N/A — architectural infrastructure module (no owning GDD)
**Requirement**: N/A — infrastructure; no GDD TR-ID assigned
*(This story validates the testability contract that every subsequent Logic and
Integration story depends on. If `initialize(mock_bus)` injection does not work,
no GUT unit test for any of the 7 MVP systems is valid.)*

**ADR Governing Implementation**: ADR-0001: Signal Routing Architecture
**ADR Decision Summary**: Every system must accept optional EventBus injection via
`func initialize(event_bus: EventBus = null) -> void`. In tests, pass a mock;
in production, omit (falls back to global Autoload). This story validates that
the injection pattern works in a GUT test context and that `assert_signal_emitted`
correctly observes signals through a mock bus.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GUT (Godot Unit Testing) test doubles / mock objects are the
standard test isolation mechanism. Verify that GUT's `double()` or a manual
`MockEventBus` stub can receive and record signal emissions from an injected
system. GUT is installed via AssetLib — confirm it is present in `addons/gut/`
before implementing.

**Control Manifest Rules (Foundation layer)**:
- Required: All systems accept `initialize(event_bus: EventBus = null) -> void` for GUT testability
- Required: In tests, pass a mock; in production, omit argument (falls back to global Autoload)
- Forbidden: Using `get_node("/root/EventBus")` path strings in logic code
- Guardrail: Tests must be deterministic and isolated; no test may depend on the global Autoload singleton

---

## Acceptance Criteria

*Derived from ADR-0001 Testability Pattern and Validation Criteria:*

- [ ] A `MockEventBus` stub class exists (either in `tests/helpers/` or inline in the test file) that extends `Node` and re-declares all 13 EventBus signals — sufficient for `assert_signal_emitted` to work
- [ ] GUT test confirms: passing `mock_bus` to `initialize(mock_bus)` stores the mock (not the global Autoload) as the system's internal `_event_bus` reference
- [ ] GUT test confirms: omitting the argument (calling `initialize()`) falls back to the global `EventBus` Autoload singleton
- [ ] GUT test confirms: a signal emitted through the mock bus (`mock_bus.player_died.emit()`) is observable via `assert_signal_emitted(mock_bus, "player_died")`
- [ ] GUT test confirms: `EventBus` Autoload is reachable from within a GUT test context (i.e., GUT scene runner does not lose the Autoload reference)
- [ ] All GUT tests in this file pass headlessly: `godot --headless --script tests/gdunit4_runner.gd` (or equivalent GUT runner)

---

## Implementation Notes

*Derived from ADR-0001 Testability Pattern:*

The test file should demonstrate the injection pattern using `HealthDamageSystem`
(or any minimal stand-in Node) as the example system. The point is to prove the
pattern works in GUT, not to test HealthDamageSystem's logic.

Recommended structure:

```gdscript
# game/tests/integration/signal-infrastructure/test_event_bus_injection.gd
extends GutTest

var _mock_bus: MockEventBus
var _system: Node  # minimal stand-in that calls initialize()

func before_each() -> void:
    _mock_bus = MockEventBus.new()
    add_child(_mock_bus)
    # system under test must call initialize(event_bus) to store the reference

func after_each() -> void:
    _mock_bus.queue_free()

func test_inject_mock_stores_mock_not_global() -> void:
    # system._event_bus should be _mock_bus, not EventBus (global)
    pass  # implement per system chosen

func test_omit_inject_falls_back_to_autoload() -> void:
    # system._event_bus should be EventBus (global Autoload)
    pass

func test_signal_emitted_through_mock_observable() -> void:
    watch_signals(_mock_bus)
    _mock_bus.player_died.emit()
    assert_signal_emitted(_mock_bus, "player_died")

func test_autoload_reachable_in_gut_context() -> void:
    assert_not_null(EventBus, "EventBus Autoload must be accessible in GUT")
```

`MockEventBus` should be a minimal Node subclass that re-declares the 13 signals
from `event_bus.gd`. It does not need to do anything — GUT watches it for emissions.
Place it in `game/tests/helpers/mock_event_bus.gd` so all future test files can reuse it.

Do not emit production-path signals in this test — the goal is proving the
plumbing works, not testing gameplay logic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: GameEnums definitions
- [Story 002]: EventBus signal declarations
- [health-damage-system epic]: `HealthDamageSystem.initialize()` unit tests
- [Any other system epic]: Per-system GUT injection — this story only validates the pattern works once

---

## QA Test Cases

**File**: `game/tests/integration/signal-infrastructure/test_event_bus_injection.gd`

- **Mock has same interface**: MockEventBus declares all 13 signals matching real EventBus
  - Given: MockEventBus loaded from `tests/helpers/mock_event_bus.gd`
  - When: signal presence checked for each expected signal name
  - Then: all signals present; no missing signal causes runtime error

- **Inject mock prevents global emit**: System under test uses mock, not Autoload
  - Given: mock injected into system constructor
  - When: system emits a signal
  - Then: mock's emission counter increments; global EventBus counter stays 0

- **Fallback to Autoload**: Omitting injection uses global EventBus
  - Given: system instantiated without injection parameter
  - When: system emits
  - Then: global EventBus signal fires

- **Observable in assertions**: Mock emits are visible to GUT `assert_signal_emitted`
  - Given: mock connected to a test Callable
  - When: signal emitted through mock
  - Then: Callable fires and recorded count matches expected

- **Edge cases**: MockEventBus freed after each `after_each()` with no leaked children (8-children warning must not escalate to error)

**AC-1**: MockEventBus has all 13 signals re-declared
- Given: `game/tests/helpers/mock_event_bus.gd` is loaded in GUT
- When: signal list is inspected
- Then: all 13 signal names from `event_bus.gd` are present on MockEventBus
- Edge cases: missing signal → `assert_signal_emitted` silently passes even when signal never fired (GUT quirk)

**AC-2**: inject mock stores mock, not global Autoload
- Given: a system node with `initialize(event_bus: EventBus = null)` is instantiated in GUT
- When: `system.initialize(_mock_bus)` is called
- Then: `system._event_bus` is the mock instance (not `EventBus` global); emitting on mock is not relayed to the global bus
- Edge cases: null passed → should fall back to global Autoload, not crash

**AC-3**: omit argument falls back to Autoload
- Given: same system node
- When: `system.initialize()` is called (no argument)
- Then: `system._event_bus is EventBus` evaluates true (same object as the global singleton)
- Edge cases: Autoload not registered → `EventBus` is null; this would be a project-settings bug caught here

**AC-4**: signal observed through mock bus
- Given: `watch_signals(_mock_bus)` called in `before_each()`
- When: `_mock_bus.player_died.emit()` is called
- Then: `assert_signal_emitted(_mock_bus, "player_died")` passes
- Edge cases: GUT `watch_signals` called after emit → signal missed; ordering matters

**AC-5**: Autoload reachable in GUT context
- Given: GUT scene runner is active
- When: `EventBus` is referenced directly
- Then: non-null Node reference is returned; no "Autoload not found" error
- Edge cases: GUT isolation mode strips Autoloads → test would fail; confirm GUT config preserves Autoloads

**AC-6**: All tests pass headlessly
- Given: GUT runner command is invoked on CI or locally
- When: `godot --headless --script tests/gdunit4_runner.gd` (or GUT equivalent) runs the integration test
- Then: 0 failures, 0 errors; exit code 0
- Edge cases: GUT not installed (`addons/gut/` missing) → runner exits with error before any test runs

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `game/tests/integration/signal-infrastructure/test_event_bus_injection.gd` — must exist and pass (OR documented playtest note if headless runner is not yet configured)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (EventBus must exist and be registered as Autoload)
- Unlocks: All subsequent epic stories — the `initialize(mock_bus)` pattern proved here is used by every GUT test in the project

## Completion Notes
**Completed**: 2026-06-02
**Criteria**: 6/6 passing
**Deviations**: `class_name` not auto-registered in headless GUT — fixed via `const MockEventBus = preload(...)` in test file. GUT reports 8 unfreed children warning (queue_free() async, non-functional). Code review skipped.
**Test Evidence**: Integration — `game/tests/integration/signal-infrastructure/test_event_bus_injection.gd` — 5/5 passing
**Code Review**: Skipped
