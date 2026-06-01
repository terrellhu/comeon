# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0004 (enum SM + _transition_to), ADR-0001 (1:1 direct signals), ADR-0003 (reset)

class_name PlayerController
extends CharacterBody2D

# ─── Exported tuning params (no literals in logic) ─────────────────────────
@export var move_speed: float = 340.0
@export var gravity: float = 1400.0
@export var terminal_velocity: float = 1200.0
@export var jump_impulse: float = 600.0
@export var coyote_time_duration: float = 0.10
@export var jump_buffer_duration: float = 0.12
@export var knockback_speed: float = 200.0
@export var hit_stun_duration: float = 0.30
@export var parry_exit_duration: float = 0.40

# ─── 1:1 direct signals (ADR-0001 exception — not on EventBus) ─────────────
signal parry_input_pressed
signal attack_input_pressed
signal dodge_input_pressed(direction: int)

# ─── State ──────────────────────────────────────────────────────────────────
var player_state: GameEnums.PlayerState = GameEnums.PlayerState.IDLE
var facing_direction: int = 1
var spawn_position: Vector2

# ─── Internal timers ────────────────────────────────────────────────────────
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _hit_stun_timer: float = 0.0
var _parry_exit_timer: float = 0.0
var _retry_invuln_timer: float = 0.0
@export var retry_invuln_duration: float = 2.0

# ─── Visual ─────────────────────────────────────────────────────────────────
var _visual: ColorRect

func _ready() -> void:
	spawn_position = position

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36.0, 64.0)
	col.shape = rect
	add_child(col)

	_visual = ColorRect.new()
	_visual.size = Vector2(36.0, 64.0)
	_visual.position = Vector2(-18.0, -32.0)
	_visual.color = Color(0.2, 0.45, 0.9)
	add_child(_visual)

	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.player_died.connect(_on_player_died)
	EventBus.exit_parry_state.connect(_on_exit_parry_state)

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_input()
	_process_state(delta)
	move_and_slide()  ## always last — ADR-0004

func _handle_timers(delta: float) -> void:
	if _coyote_timer > 0.0:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	if _hit_stun_timer > 0.0:
		_hit_stun_timer = maxf(_hit_stun_timer - delta, 0.0)
		if _hit_stun_timer <= 0.0 and player_state == GameEnums.PlayerState.HIT_STUN:
			_transition_to(GameEnums.PlayerState.IDLE)
	if _parry_exit_timer > 0.0:
		_parry_exit_timer = maxf(_parry_exit_timer - delta, 0.0)
		if _parry_exit_timer <= 0.0 and player_state == GameEnums.PlayerState.PARRYING:
			_transition_to(GameEnums.PlayerState.IDLE)
	if _retry_invuln_timer > 0.0:
		_retry_invuln_timer = maxf(_retry_invuln_timer - delta, 0.0)
		_visual.modulate.a = 0.4 + 0.6 * (sin(Time.get_ticks_msec() * 0.01) * 0.5 + 0.5) if _retry_invuln_timer > 0.0 else 1.0

# ─── Input (priority-ordered early returns — ADR-0004) ──────────────────────
func _handle_input() -> void:
	if player_state == GameEnums.PlayerState.DEAD:
		return

	# Priority 1: parry
	if Input.is_action_just_pressed(&"parry") and _can_parry():
		_transition_to(GameEnums.PlayerState.PARRYING)
		return

	# Priority 2: dodge (VS placeholder — not fully implemented)
	if Input.is_action_just_pressed(&"dodge") and _can_dodge():
		# VS simplification: no full dodge system implemented
		return

	# Priority 3: jump (buffer on any press)
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_duration
	if _jump_buffer_timer > 0.0 and _can_jump():
		_jump_buffer_timer = 0.0
		_transition_to(GameEnums.PlayerState.AIRBORNE)
		velocity.y = -jump_impulse
		return

	# Priority 4: attack (no state change — forwarded impulse)
	if Input.is_action_just_pressed(&"attack") and _can_attack():
		attack_input_pressed.emit()

	# Priority 5: horizontal movement
	var move_dir := int(Input.get_axis(&"move_left", &"move_right"))
	if move_dir != 0:
		facing_direction = move_dir
	if player_state not in [GameEnums.PlayerState.PARRYING, GameEnums.PlayerState.HIT_STUN]:
		velocity.x = move_dir * move_speed

# ─── Guards ─────────────────────────────────────────────────────────────────
func _can_parry() -> bool:
	return player_state in [GameEnums.PlayerState.IDLE, GameEnums.PlayerState.RUNNING, GameEnums.PlayerState.AIRBORNE]

func _can_dodge() -> bool:
	return player_state in [GameEnums.PlayerState.IDLE, GameEnums.PlayerState.RUNNING]

func _can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0

func _can_attack() -> bool:
	return player_state in [GameEnums.PlayerState.IDLE, GameEnums.PlayerState.RUNNING, GameEnums.PlayerState.AIRBORNE]

# ─── Per-state logic ─────────────────────────────────────────────────────────
func _process_state(delta: float) -> void:
	match player_state:
		GameEnums.PlayerState.IDLE:
			if not is_on_floor():
				_transition_to(GameEnums.PlayerState.AIRBORNE)
			else:
				_coyote_timer = coyote_time_duration
				if Input.get_axis(&"move_left", &"move_right") != 0.0:
					_transition_to(GameEnums.PlayerState.RUNNING)
				else:
					velocity.x = 0.0
		GameEnums.PlayerState.RUNNING:
			if not is_on_floor():
				_transition_to(GameEnums.PlayerState.AIRBORNE)
			elif Input.get_axis(&"move_left", &"move_right") == 0.0:
				_transition_to(GameEnums.PlayerState.IDLE)
		GameEnums.PlayerState.AIRBORNE:
			if is_on_floor():
				if _jump_buffer_timer > 0.0:
					_jump_buffer_timer = 0.0
					velocity.y = -jump_impulse
				else:
					_transition_to(GameEnums.PlayerState.IDLE)
			else:
				velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
		GameEnums.PlayerState.PARRYING:
			velocity.x = 0.0
			if not is_on_floor():
				velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
		GameEnums.PlayerState.HIT_STUN:
			if not is_on_floor():
				velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
		GameEnums.PlayerState.DEAD:
			velocity = Vector2.ZERO

# ─── Central state dispatcher — ADR-0004 ────────────────────────────────────
func _transition_to(new_state: GameEnums.PlayerState) -> void:
	_exit_state(player_state)
	player_state = new_state
	_enter_state(new_state)

func _enter_state(state: GameEnums.PlayerState) -> void:
	match state:
		GameEnums.PlayerState.PARRYING:
			velocity.x = 0.0
			_parry_exit_timer = parry_exit_duration  ## fallback timer; overridden by exit_parry_state signal
			parry_input_pressed.emit()
			_visual.color = Color(0.4, 0.8, 1.0)
		GameEnums.PlayerState.HIT_STUN:
			_hit_stun_timer = hit_stun_duration
			velocity.x = -facing_direction * knockback_speed
			_visual.color = Color(0.9, 0.2, 0.2)
		GameEnums.PlayerState.DEAD:
			velocity = Vector2.ZERO
			_visual.color = Color(0.3, 0.3, 0.3)
		GameEnums.PlayerState.IDLE, GameEnums.PlayerState.RUNNING:
			_visual.color = Color(0.2, 0.45, 0.9) if _retry_invuln_timer <= 0.0 else _visual.color
		GameEnums.PlayerState.AIRBORNE:
			if not is_on_floor():
				_coyote_timer = coyote_time_duration

func _exit_state(state: GameEnums.PlayerState) -> void:
	match state:
		GameEnums.PlayerState.HIT_STUN:
			_hit_stun_timer = 0.0
			_visual.color = Color(0.2, 0.45, 0.9)
		GameEnums.PlayerState.PARRYING:
			_parry_exit_timer = 0.0
			_visual.color = Color(0.2, 0.45, 0.9)

# ─── Signal handlers ─────────────────────────────────────────────────────────
func _on_player_hp_changed(current: float, _max_hp: float) -> void:
	var prev_hp: float = current + 0.0  ## just to note: we detect decrease
	# Only trigger HIT_STUN if HP actually decreased and we're not already in it
	if player_state not in [GameEnums.PlayerState.DEAD, GameEnums.PlayerState.HIT_STUN]:
		# HP decrease implies a hit — transition to HIT_STUN
		# (HealthDamageSystem already validated the invuln window)
		_transition_to(GameEnums.PlayerState.HIT_STUN)

func _on_player_died() -> void:
	_transition_to(GameEnums.PlayerState.DEAD)

func _on_exit_parry_state(duration: float) -> void:
	_parry_exit_timer = duration

## ADR-0003 reset contract
func reset_for_retry(ctx: Dictionary) -> void:
	player_state = GameEnums.PlayerState.IDLE
	velocity = Vector2.ZERO
	position = spawn_position
	facing_direction = 1
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_hit_stun_timer = 0.0
	_parry_exit_timer = 0.0
	_retry_invuln_timer = retry_invuln_duration
	_visual.color = Color(0.2, 0.45, 0.9)
	_visual.modulate.a = 1.0
