# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
#
# Arena bootstrap: creates scene tree programmatically, wires all signals,
# initializes all systems in ADR-0003 dependency order.

extends Node2D

const ARENA_W := 1280.0
const ARENA_H := 720.0
const FLOOR_Y := 580.0          ## top of floor
const PLAYER_START := Vector2(200.0, FLOOR_Y - 32.0)   ## player spawn (standing on floor)
const BOSS_POS := Vector2(960.0, FLOOR_Y - 55.0)       ## boss anchor

## System references (injected after creation)
var _health_system: HealthDamageSystem
var _player: PlayerController
var _boss_sm: BossStateMachine
var _parry_system: ParryTelegraphSystem
var _counter_system: CounterAttackComboSystem
var _retry_system: InstantRetrySystem
var _hud: HUDSystem
var _boss_data_loader: BossDataLoader
var _boss_data: BossData

func _ready() -> void:
	_setup_input_map()
	_build_arena()
	_create_systems()
	_initialize_systems()
	_wire_direct_signals()
	print("=== Blade Echo VS ready — Press X=Parry Z=Attack ←→=Move Space=Jump ===")

## ─── Input map (programmatic — avoids project.godot complexity) ──────────────
func _setup_input_map() -> void:
	_add_key_action(&"parry",      KEY_X)
	_add_key_action(&"attack",     KEY_Z)
	_add_key_action(&"move_left",  KEY_LEFT)
	_add_key_action(&"move_right", KEY_RIGHT)
	_add_key_action(&"jump",       KEY_SPACE)
	_add_key_action(&"dodge",      KEY_SHIFT)

func _add_key_action(action: StringName, key_code: Key) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = key_code
	InputMap.action_add_event(action, event)

## ─── Arena scene ──────────────────────────────────────────────────────────────
func _build_arena() -> void:
	# Background
	var bg := ColorRect.new()
	bg.size = Vector2(ARENA_W, ARENA_H)
	bg.color = Color(0.06, 0.05, 0.10)  ## dark indigo — approximates Art Bible palette
	add_child(bg)

	# Floor platform
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(ARENA_W / 2.0, FLOOR_Y + 20.0)
	var floor_col := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(ARENA_W, 40.0)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	var floor_vis := ColorRect.new()
	floor_vis.size = Vector2(ARENA_W, 40.0)
	floor_vis.position = Vector2(-ARENA_W / 2.0, -20.0)
	floor_vis.color = Color(0.15, 0.12, 0.18)
	floor_body.add_child(floor_vis)
	add_child(floor_body)

	# Left wall
	var lw := _make_wall(Vector2(-20.0, ARENA_H / 2.0), Vector2(40.0, ARENA_H))
	add_child(lw)
	# Right wall
	var rw := _make_wall(Vector2(ARENA_W + 20.0, ARENA_H / 2.0), Vector2(40.0, ARENA_H))
	add_child(rw)

	# Control hints label
	var hint := Label.new()
	hint.position = Vector2(20.0, 8.0)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	hint.text = "← → Move  Space Jump  X Parry  Z Attack"
	add_child(hint)

func _make_wall(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return body

## ─── Systems ───────────────────────────────────────────────────────────────────
func _create_systems() -> void:
	# BossDataLoader (Foundation)
	_boss_data_loader = BossDataLoader.new()
	add_child(_boss_data_loader)
	_boss_data = _boss_data_loader.make_test_data()

	# HealthDamageSystem (Core)
	_health_system = HealthDamageSystem.new()
	add_child(_health_system)

	# PlayerController (Core)
	_player = PlayerController.new()
	_player.position = PLAYER_START
	add_child(_player)

	# BossStateMachine (Feature) — lives on the boss node
	_boss_sm = BossStateMachine.new()
	_boss_sm.position = BOSS_POS
	add_child(_boss_sm)

	# ParryTelegraphSystem (Feature)
	_parry_system = ParryTelegraphSystem.new()
	add_child(_parry_system)

	# CounterAttackComboSystem (Feature)
	_counter_system = CounterAttackComboSystem.new()
	add_child(_counter_system)

	# InstantRetrySystem (Feature) — PROCESS_MODE_ALWAYS set in its _ready
	_retry_system = InstantRetrySystem.new()
	add_child(_retry_system)

	# HUDSystem (Presentation — CanvasLayer)
	_hud = HUDSystem.new()
	add_child(_hud)

func _initialize_systems() -> void:
	# ADR-0003 initialisation order:
	# 1. EventBus, RetryContext, HitpauseManager — already initialised as Autoloads
	# 2. BossDataLoader — already initialised above
	# 3. HealthDamageSystem
	_health_system.initialize(_boss_data)

	# 4. PlayerController — _ready() already wired; set spawn position reference
	_player.spawn_position = PLAYER_START

	# 5. BossStateMachine
	_boss_sm.initialize(_boss_data)

	# 6. ParryTelegraphSystem — inject HealthDamageSystem
	_parry_system.set_health_system(_health_system)

	# 7. CounterAttackComboSystem — inject HealthDamageSystem
	_counter_system.set_health_system(_health_system)

	# 8. InstantRetrySystem — inject all system references
	_retry_system.health_system    = _health_system
	_retry_system.player_controller = _player
	_retry_system.boss_state_machine = _boss_sm
	_retry_system.parry_system     = _parry_system
	_retry_system.counter_system   = _counter_system
	_retry_system.hud_system       = _hud

	# 9. HUDSystem — give it boss_data for phase threshold lines
	_hud.initialize(_boss_data)

func _wire_direct_signals() -> void:
	# 1:1 direct signals — ADR-0001 exception (PlayerController → subsystems)
	_player.parry_input_pressed.connect(_parry_system.on_parry_input_pressed)
	_player.attack_input_pressed.connect(_counter_system.on_attack_input_pressed)
	# dodge_input_pressed: VS does not implement full dodge system; no-op connection
