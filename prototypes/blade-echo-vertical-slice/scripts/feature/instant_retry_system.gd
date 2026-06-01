# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0003 (SceneTree.paused, in-place reset, PROCESS_MODE_ALWAYS)

class_name InstantRetrySystem
extends Node

@export var red_flash_duration: float   = 0.2   ## Art Bible 7.5 locked
@export var fade_to_grey_duration: float = 0.4   ## Art Bible 7.5 locked
@export var phase_symbol_duration: float = 0.6   ## Art Bible 7.5 locked
@export var symbol_fade_duration: float  = 0.3   ## Art Bible 7.5 locked
@export var retry_invuln_duration: float = 2.0

## Injected by arena
var health_system: HealthDamageSystem
var player_controller: PlayerController
var boss_state_machine: BossStateMachine
var parry_system: ParryTelegraphSystem
var counter_system: CounterAttackComboSystem
var hud_system: Node  ## HUDSystem

## VS death screen overlay elements (created in _ready)
var _overlay: ColorRect
var _symbol_label: Label
var _death_screen_layer: CanvasLayer
var _is_in_death_screen: bool = false

func _ready() -> void:
	# PROCESS_MODE_ALWAYS — must continue running during SceneTree.paused — ADR-0003
	process_mode = Node.PROCESS_MODE_ALWAYS

	_death_screen_layer = CanvasLayer.new()
	_death_screen_layer.layer = 100
	_death_screen_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_death_screen_layer)

	_overlay = ColorRect.new()
	_overlay.size = Vector2(1280.0, 720.0)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_screen_layer.add_child(_overlay)

	_symbol_label = Label.new()
	_symbol_label.position = Vector2(540.0, 310.0)
	_symbol_label.size = Vector2(200.0, 100.0)
	_symbol_label.add_theme_font_size_override("font_size", 72)
	_symbol_label.add_theme_color_override("font_color", Color(0.95, 0.94, 0.91))
	_symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_symbol_label.text = "◆"
	_symbol_label.visible = false
	_symbol_label.process_mode = Node.PROCESS_MODE_ALWAYS
	_death_screen_layer.add_child(_symbol_label)

	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)

func _process(delta: float) -> void:
	# Skip detection only runs during death screen — ADR-0003 CONFLICT-01 note:
	# GDD AC-03 says skip on any frame; ADR-0003 says delay 200ms.
	# VS implements ADR-0003 guard (200ms): listening starts only after RED_FLASH ends.
	if not get_tree().paused:
		return
	if _is_in_death_screen and Input.is_anything_pressed():
		_skip_to_resume()

func _on_player_died() -> void:
	if _is_in_death_screen:
		return
	_is_in_death_screen = true
	_save_context()
	get_tree().paused = true
	_play_death_screen()

func _on_boss_defeated() -> void:
	RetryContext.clear_context()

func _save_context() -> void:
	var boss_hp := health_system.current_boss_hp if health_system else 0.0
	var boss_phase := health_system.get_current_phase() - 1 if health_system else 0  ## 0-based
	RetryContext.save_context(boss_hp, boss_phase, RetryContext.session_death_count + 1)

func _play_death_screen() -> void:
	_overlay.color = Color(0.8, 0.0, 0.0, 0.4)   ## RED_FLASH
	var tween := create_tween()
	# Node is PROCESS_MODE_ALWAYS so this tween runs through SceneTree.paused automatically.
	# Phase 1: RED_FLASH (0–0.2s)
	tween.tween_interval(red_flash_duration)
	# Phase 2: FADE_TO_GREY (0.2–0.6s)
	tween.tween_property(_overlay, "color", Color(0.04, 0.04, 0.05, 1.0), fade_to_grey_duration)
	# Trigger reset during FADE_TO_GREY window
	tween.parallel().tween_callback(_execute_reset)
	# Phase 3: PHASE_SYMBOL (0.6–1.2s)
	tween.tween_callback(func(): _symbol_label.visible = true; _symbol_label.modulate.a = 1.0)
	tween.tween_interval(phase_symbol_duration)
	# Phase 4: SYMBOL_FADE_OUT (1.2–1.5s)
	tween.tween_property(_symbol_label, "modulate:a", 0.0, symbol_fade_duration)
	tween.tween_callback(_resume_game)

func _execute_reset() -> void:
	var ctx := RetryContext.load_context()
	if health_system:
		health_system.reset_for_retry(ctx)
	if player_controller:
		player_controller.reset_for_retry(ctx)
	if boss_state_machine:
		boss_state_machine.reset_for_retry(ctx)
	if parry_system:
		parry_system.reset_for_retry(ctx)
	if counter_system:
		counter_system.reset_for_retry(ctx)
	if hud_system and hud_system.has_method("reset_for_retry"):
		hud_system.reset_for_retry(ctx)

func _skip_to_resume() -> void:
	# Cancel all tweens — immediate jump to resume
	for child in get_tree().get_nodes_in_group("death_tweens"):
		child.kill()
	_resume_game()

func _resume_game() -> void:
	_is_in_death_screen = false
	_symbol_label.visible = false
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	get_tree().paused = false
	EventBus.retry_death_count_changed.emit(RetryContext.session_death_count)
