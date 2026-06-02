extends GutTest

# No class_name — GUT test files must not register a global class.
#
# AC-5/AC-6 verified via grep (not a GUT test):
#   grep 'connect("' game/**/*.gd  →  0 matches
#   grep 'emit("'    game/**/*.gd  →  0 matches

var _eb_script = load("res://autoloads/event_bus.gd")
var _eb  # untyped — avoids parse-time `is Node` check issue


func before_each() -> void:
	_eb = _eb_script.new()


func after_each() -> void:
	_eb.free()


# ─── AC-2: EventBus extends Node ─────────────────────────────────────────────

func test_event_bus_extends_node() -> void:
	assert_true(_eb is Node, "EventBus must extend Node")


# ─── AC-1: All 13 signals exist ──────────────────────────────────────────────

func test_has_signal_attack_telegraphed() -> void:
	assert_true(_eb.has_signal("attack_telegraphed"), "attack_telegraphed signal must exist")


func test_has_signal_parry_succeeded() -> void:
	assert_true(_eb.has_signal("parry_succeeded"), "parry_succeeded signal must exist")


func test_has_signal_parry_failed() -> void:
	assert_true(_eb.has_signal("parry_failed"), "parry_failed signal must exist")


func test_has_signal_stagger_ended() -> void:
	assert_true(_eb.has_signal("stagger_ended"), "stagger_ended signal must exist")


func test_has_signal_counter_full_combo_completed() -> void:
	assert_true(_eb.has_signal("counter_full_combo_completed"), "counter_full_combo_completed signal must exist")


func test_has_signal_player_died() -> void:
	assert_true(_eb.has_signal("player_died"), "player_died signal must exist")


func test_has_signal_player_hp_changed() -> void:
	assert_true(_eb.has_signal("player_hp_changed"), "player_hp_changed signal must exist")


func test_has_signal_boss_defeated() -> void:
	assert_true(_eb.has_signal("boss_defeated"), "boss_defeated signal must exist")


func test_has_signal_boss_phase_changed() -> void:
	assert_true(_eb.has_signal("boss_phase_changed"), "boss_phase_changed signal must exist")


func test_has_signal_boss_hp_changed() -> void:
	assert_true(_eb.has_signal("boss_hp_changed"), "boss_hp_changed signal must exist")


func test_has_signal_telegraph_updated() -> void:
	assert_true(_eb.has_signal("telegraph_updated"), "telegraph_updated signal must exist")


func test_has_signal_counter_window_updated() -> void:
	assert_true(_eb.has_signal("counter_window_updated"), "counter_window_updated signal must exist")


func test_has_signal_retry_death_count_changed() -> void:
	assert_true(_eb.has_signal("retry_death_count_changed"), "retry_death_count_changed signal must exist")


# ─── AC-4: Autoload accessible as global (best-effort; may skip in headless) ─

func test_eventbus_autoload_is_accessible() -> void:
	# Autoloads are scene-tree nodes under /root, not Engine singletons.
	# Passes when project.godot has EventBus registered and tests run with --path .
	var node = get_node_or_null("/root/EventBus")
	assert_not_null(node, "EventBus autoload must be present at /root/EventBus")
