extends GutTest

# No class_name — GUT test files must not register a global class.
# class_name registration from tests/helpers/ is not available in headless mode;
# use preload to create a local alias instead.
const MockEventBus = preload("res://tests/helpers/mock_event_bus.gd")


## Minimal injectable system used only in this test file.
## Demonstrates the initialize(event_bus) injection pattern from ADR-0001.
class _InjectableSystem extends Node:
	## Untyped as Node (not EventBus) — event_bus.gd has no class_name.
	var _event_bus: Node = null

	## Production usage: initialize()          → falls back to global Autoload
	## Test usage:       initialize(mock_bus)  → stores mock
	func initialize(event_bus: Node = null) -> void:
		if event_bus != null:
			_event_bus = event_bus
		else:
			_event_bus = get_node_or_null("/root/EventBus")


var _mock_bus: MockEventBus
var _system: Node  # holds an _InjectableSystem instance


func before_each() -> void:
	_mock_bus = MockEventBus.new()
	add_child(_mock_bus)
	watch_signals(_mock_bus)  # must be called before any emit (AC-4 ordering)


func after_each() -> void:
	if is_instance_valid(_system):
		_system.queue_free()
		_system = null
	_mock_bus.queue_free()


# ─── AC-1: MockEventBus declares all 13 signals ───────────────────────────────

func test_mock_event_bus_has_all_13_signals() -> void:
	assert_true(_mock_bus.has_signal("attack_telegraphed"),           "attack_telegraphed must exist on mock")
	assert_true(_mock_bus.has_signal("parry_succeeded"),              "parry_succeeded must exist on mock")
	assert_true(_mock_bus.has_signal("parry_failed"),                 "parry_failed must exist on mock")
	assert_true(_mock_bus.has_signal("stagger_ended"),                "stagger_ended must exist on mock")
	assert_true(_mock_bus.has_signal("counter_full_combo_completed"), "counter_full_combo_completed must exist on mock")
	assert_true(_mock_bus.has_signal("player_died"),                  "player_died must exist on mock")
	assert_true(_mock_bus.has_signal("player_hp_changed"),            "player_hp_changed must exist on mock")
	assert_true(_mock_bus.has_signal("boss_defeated"),                "boss_defeated must exist on mock")
	assert_true(_mock_bus.has_signal("boss_phase_changed"),           "boss_phase_changed must exist on mock")
	assert_true(_mock_bus.has_signal("boss_hp_changed"),              "boss_hp_changed must exist on mock")
	assert_true(_mock_bus.has_signal("telegraph_updated"),            "telegraph_updated must exist on mock")
	assert_true(_mock_bus.has_signal("counter_window_updated"),       "counter_window_updated must exist on mock")
	assert_true(_mock_bus.has_signal("retry_death_count_changed"),    "retry_death_count_changed must exist on mock")


# ─── AC-2: inject mock stores mock, not global Autoload ───────────────────────

func test_inject_mock_stores_mock_not_global() -> void:
	_system = _InjectableSystem.new()
	add_child(_system)

	_system.initialize(_mock_bus)

	assert_eq((_system as _InjectableSystem)._event_bus, _mock_bus,
		"_event_bus must be the injected mock, not the global Autoload")


# ─── AC-3: omit argument falls back to global Autoload ────────────────────────

func test_omit_inject_falls_back_to_autoload() -> void:
	_system = _InjectableSystem.new()
	add_child(_system)
	var global_bus: Node = get_node_or_null("/root/EventBus")

	_system.initialize()

	assert_not_null((_system as _InjectableSystem)._event_bus,
		"_event_bus must not be null after initialize() with no argument")
	assert_eq((_system as _InjectableSystem)._event_bus, global_bus,
		"_event_bus must be the global EventBus Autoload node at /root/EventBus")


# ─── AC-4: signal emitted through mock is observable by GUT ──────────────────

func test_signal_emitted_through_mock_is_observable() -> void:
	_mock_bus.player_died.emit()

	assert_signal_emitted(_mock_bus, "player_died")


# ─── AC-5: EventBus Autoload is reachable from GUT context ───────────────────

func test_eventbus_autoload_reachable_in_gut_context() -> void:
	assert_not_null(get_node_or_null("/root/EventBus"),
		"EventBus must be present at /root/EventBus in the GUT scene tree")
