# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0005 (CONNECT_ONE_SHOT), ADR-0002 (BossData-driven), ADR-0003 (reset)

class_name BossStateMachine
extends Node2D

# ─── Animation name constants — ADR-0005 ───────────────────────────────────
const ANIM_IDLE: StringName             = &"idle"
const ANIM_ATTACK_LIGHT: StringName     = &"attack_light"
const ANIM_ATTACK_HEAVY: StringName     = &"attack_heavy"
const ANIM_ATTACK_SWEEP: StringName     = &"attack_sweep"
const ANIM_STAGGERED: StringName        = &"staggered"
const ANIM_PHASE_TRANSITION: StringName = &"phase_transition"
const ANIM_DEFEAT: StringName           = &"defeat"

enum BehaviorState { IDLE, TELEGRAPHING, ATTACKING, STAGGERED, PHASE_TRANSITION, DEFEATED }

@export var idle_start_delay: float = 1.5   ## grace period before first attack

var _behavior_state: BehaviorState = BehaviorState.IDLE
var _phase_index: int = 0
var _sequence_index: int = 0
var _idle_timer: float = 0.0
var _internal_telegraph_timer: float = 0.0
var _pending_phase_change: bool = false
var _pending_to_phase: int = -1
var _current_attack: AttackData = null
var _current_phase_data: PhaseData = null
var _boss_data: BossData

## VS visual — Boss is a ColorRect driven by state
var _boss_visual: ColorRect
var _phase_label: Label
var _anim_player: AnimationPlayer

func _ready() -> void:
	_boss_visual = ColorRect.new()
	_boss_visual.size = Vector2(90.0, 110.0)
	_boss_visual.position = Vector2(-45.0, -55.0)
	_boss_visual.color = Color(0.55, 0.08, 0.08)
	add_child(_boss_visual)

	_phase_label = Label.new()
	_phase_label.position = Vector2(-40.0, -80.0)
	_phase_label.add_theme_font_size_override("font_size", 14)
	_phase_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_phase_label.text = "Phase 1"
	add_child(_phase_label)

	EventBus.parry_succeeded.connect(_on_parry_succeeded)
	EventBus.stagger_ended.connect(_on_stagger_ended)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.parry_failed.connect(_on_parry_failed)
	EventBus.player_died.connect(_on_player_died)

func initialize(boss_data: BossData) -> void:
	_boss_data = boss_data
	_phase_index = 0
	_sequence_index = 0
	_current_phase_data = boss_data.phases[0]
	_anim_player = _create_animation_player()
	add_child(_anim_player)
	_idle_timer = idle_start_delay

func _create_animation_player() -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.process_mode = Node.PROCESS_MODE_PAUSABLE
	var lib := AnimationLibrary.new()

	for entry in [
		[ANIM_IDLE, 0.5],
		[ANIM_ATTACK_LIGHT, 0.5],
		[ANIM_ATTACK_HEAVY, 0.8],
		[ANIM_ATTACK_SWEEP, 1.0],
		[ANIM_STAGGERED, 0.05],
		[ANIM_PHASE_TRANSITION, 0.6],
		[ANIM_DEFEAT, 1.5],
	]:
		var anim := Animation.new()
		anim.length = entry[1]
		lib.add_animation(entry[0], anim)

	ap.add_animation_library(&"", lib)
	return ap

func _physics_process(delta: float) -> void:
	_update_visual()
	match _behavior_state:
		BehaviorState.IDLE:
			_idle_timer = maxf(_idle_timer - delta, 0.0)
			if _idle_timer <= 0.0:
				_start_next_attack()
		BehaviorState.TELEGRAPHING:
			_internal_telegraph_timer = minf(
				_internal_telegraph_timer + delta,
				_get_effective_telegraph_duration()
			)
			# Telegraph expiry handled by ParryTelegraphSystem; we just track for visual.
			# If the parry system didn't intercept and attack_telegraphed was emitted,
			# we transition to ATTACKING after the telegraph window via a small watch:
			if _internal_telegraph_timer >= _get_effective_telegraph_duration():
				_transition_to(BehaviorState.ATTACKING)

func _start_next_attack() -> void:
	if _current_phase_data == null or _current_phase_data.attack_sequence.is_empty():
		return
	_current_attack = _current_phase_data.attack_sequence[_sequence_index]
	var effective_duration := _get_effective_telegraph_duration()
	_internal_telegraph_timer = 0.0
	_transition_to(BehaviorState.TELEGRAPHING)
	EventBus.attack_telegraphed.emit(_current_attack.attack_type, _current_attack.damage)

func _get_effective_telegraph_duration() -> float:
	if _current_attack == null:
		return 1.0
	if _current_attack.telegraph_duration_override > 0.0:
		return _current_attack.telegraph_duration_override
	match _current_attack.attack_type:
		GameEnums.AttackType.LIGHT: return 0.8
		GameEnums.AttackType.HEAVY: return 1.2
		GameEnums.AttackType.SWEEP: return 1.5
	return 0.8

func _transition_to(new_state: BehaviorState) -> void:
	_exit_state(_behavior_state)
	_behavior_state = new_state
	_enter_state(new_state)

func _enter_state(state: BehaviorState) -> void:
	match state:
		BehaviorState.TELEGRAPHING:
			_anim_player.play(ANIM_IDLE)  ## Boss holds stance during telegraph
		BehaviorState.ATTACKING:
			var anim_name := _get_attack_anim_name()
			_anim_player.play(anim_name)
			# CONNECT_ONE_SHOT — ADR-0005: drives ATTACKING→IDLE transition
			_anim_player.animation_finished.connect(_on_attack_animation_done, CONNECT_ONE_SHOT)
		BehaviorState.STAGGERED:
			_anim_player.play(ANIM_STAGGERED)
		BehaviorState.PHASE_TRANSITION:
			_anim_player.play(ANIM_PHASE_TRANSITION)
			_anim_player.animation_finished.connect(_on_phase_transition_done, CONNECT_ONE_SHOT)
		BehaviorState.DEFEATED:
			_anim_player.play(ANIM_DEFEAT)
		BehaviorState.IDLE:
			_idle_timer = _current_phase_data.idle_duration_after_attack if _current_phase_data else 0.5
			_anim_player.play(ANIM_IDLE)

func _exit_state(state: BehaviorState) -> void:
	match state:
		BehaviorState.ATTACKING:
			# CRITICAL — ADR-0005: cancel pending callback on interrupt
			if _anim_player and _anim_player.animation_finished.is_connected(_on_attack_animation_done):
				_anim_player.animation_finished.disconnect(_on_attack_animation_done)
		BehaviorState.PHASE_TRANSITION:
			if _anim_player and _anim_player.animation_finished.is_connected(_on_phase_transition_done):
				_anim_player.animation_finished.disconnect(_on_phase_transition_done)

func _get_attack_anim_name() -> StringName:
	if _current_attack == null:
		return ANIM_ATTACK_LIGHT
	match _current_attack.attack_type:
		GameEnums.AttackType.LIGHT: return ANIM_ATTACK_LIGHT
		GameEnums.AttackType.HEAVY: return ANIM_ATTACK_HEAVY
		GameEnums.AttackType.SWEEP: return ANIM_ATTACK_SWEEP
	return ANIM_ATTACK_LIGHT

func _advance_sequence() -> void:
	if _current_phase_data == null:
		return
	_sequence_index = (_sequence_index + 1) % _current_phase_data.attack_sequence.size()

func _on_attack_animation_done(_anim_name: StringName) -> void:
	if _behavior_state != BehaviorState.ATTACKING:
		return  ## guard — ADR-0005
	_advance_sequence()
	_transition_to(BehaviorState.IDLE)
	if _pending_phase_change:
		_pending_phase_change = false
		_execute_phase_transition(_pending_to_phase)

func _on_phase_transition_done(_anim_name: StringName) -> void:
	if _behavior_state != BehaviorState.PHASE_TRANSITION:
		return
	_sequence_index = 0
	_transition_to(BehaviorState.IDLE)

func _on_parry_succeeded(_attack_type: GameEnums.AttackType) -> void:
	if _behavior_state == BehaviorState.DEFEATED:
		return
	_transition_to(BehaviorState.STAGGERED)

func _on_stagger_ended() -> void:
	if _behavior_state != BehaviorState.STAGGERED:
		return
	_advance_sequence()
	if _pending_phase_change:
		_pending_phase_change = false
		_execute_phase_transition(_pending_to_phase)
	else:
		_transition_to(BehaviorState.IDLE)

func _on_boss_phase_changed(_from: int, to: int) -> void:
	match _behavior_state:
		BehaviorState.IDLE:
			_execute_phase_transition(to - 1)  ## to is 1-based; phases array is 0-based
		BehaviorState.TELEGRAPHING, BehaviorState.ATTACKING:
			_pending_phase_change = true
			_pending_to_phase = to - 1
		BehaviorState.STAGGERED:
			_pending_phase_change = true
			_pending_to_phase = to - 1

func _execute_phase_transition(phase_index: int) -> void:
	if phase_index >= _boss_data.phases.size():
		return
	_phase_index = phase_index
	_current_phase_data = _boss_data.phases[phase_index]
	_sequence_index = 0
	_phase_label.text = "Phase %d" % (phase_index + 1)
	_transition_to(BehaviorState.PHASE_TRANSITION)

func _on_boss_defeated() -> void:
	_transition_to(BehaviorState.DEFEATED)

func _on_parry_failed(_attack_type: GameEnums.AttackType) -> void:
	pass  ## VS: no hit-reaction layer animation

func _on_player_died() -> void:
	pass  ## Boss continues unchanged on player death (HP preserved)

func _update_visual() -> void:
	match _behavior_state:
		BehaviorState.IDLE:
			_boss_visual.color = Color(0.55, 0.08, 0.08)
		BehaviorState.TELEGRAPHING:
			var progress := _internal_telegraph_timer / maxf(_get_effective_telegraph_duration(), 0.001)
			_boss_visual.color = Color(
				lerpf(0.55, 1.0, progress),
				lerpf(0.08, 0.4, progress),
				0.0
			)
		BehaviorState.ATTACKING:
			_boss_visual.color = Color(0.9, 0.05, 0.05)
		BehaviorState.STAGGERED:
			_boss_visual.color = Color(0.4, 0.4, 0.55)
		BehaviorState.PHASE_TRANSITION:
			_boss_visual.color = Color(0.95, 0.95, 0.95)
		BehaviorState.DEFEATED:
			_boss_visual.color = Color(0.05, 0.05, 0.05)

func reset_for_retry(ctx: Dictionary) -> void:
	var phase: int = ctx.get("boss_phase", 0)
	_phase_index = clampi(phase, 0, _boss_data.phases.size() - 1)
	_current_phase_data = _boss_data.phases[_phase_index]
	_sequence_index = 0
	_idle_timer = idle_start_delay
	_internal_telegraph_timer = 0.0
	_pending_phase_change = false
	_behavior_state = BehaviorState.IDLE
	_phase_label.text = "Phase %d" % (_phase_index + 1)
	if _anim_player:
		_anim_player.stop()
		_anim_player.play(ANIM_IDLE)
	_boss_visual.color = Color(0.55, 0.08, 0.08)
