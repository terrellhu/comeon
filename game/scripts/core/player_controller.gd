class_name PlayerController
extends CharacterBody2D

# ─── Constants ────────────────────────────────────────────────────────────────

const MAX_HIT_STUN_DURATION: float = 0.5

# ─── Signals ─────────────────────────────────────────────────────────────────
## Emitted when the player presses parry input (Story 003 wires emission).
signal parry_input_pressed
## Emitted when the player presses attack input (Story 006 wires emission).
signal attack_input_pressed
## Emitted when the player presses dodge input; direction matches facing_direction.
## (Story 005 wires emission.)
signal dodge_input_pressed(direction: int)

# ─── Export parameters (no numeric literals in logic code) ───────────────────
@export_group("Movement")
@export var move_speed: float = 340.0
@export var gravity: float = 1400.0
@export var terminal_velocity: float = 1200.0
@export var jump_impulse: float = 600.0

@export_group("Timers")
@export var coyote_time_duration: float = 0.10
@export var jump_buffer_duration: float = 0.12

@export_group("Combat")
@export var knockback_speed: float = 200.0
## Designer-tunable hit-stun duration; clamped to [0, 0.5 s] (player_hit_invuln_duration max).
## Backing var _hit_stun_duration lives in Private state section below.
@export var hit_stun_duration: float = 0.30:
	get:
		return _hit_stun_duration
	set(value):
		if value > MAX_HIT_STUN_DURATION or value < 0.0:
			push_warning(
				"PlayerController: hit_stun_duration %f out of range [0, %f]; clamping." \
				% [value, MAX_HIT_STUN_DURATION]
			)
		_hit_stun_duration = clampf(value, 0.0, MAX_HIT_STUN_DURATION)

@export_group("Spawn")
## Set automatically in _ready() from initial scene position.
## Can be overridden in the editor for level-specific spawn points.
@export var spawn_position: Vector2

# ─── Public state ─────────────────────────────────────────────────────────────
## Current state in the player state machine. Read externally; mutate only via
## _transition_to().
var player_state: GameEnums.PlayerState = GameEnums.PlayerState.IDLE

## Last committed horizontal direction: 1 = right, -1 = left.
var facing_direction: int = 1

# ─── Private state ────────────────────────────────────────────────────────────
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _jumped_this_frame: bool = false   # true when jump was initiated this frame
var _hit_stun_timer: float = 0.0
var _parry_exit_timer: float = 0.0
## Backing var for the hit_stun_duration @export property (validated setter above).
var _hit_stun_duration: float = 0.30
## Reserved for Story 004 (EventBus hp-change subscription).
var _prev_hp: float = 0.0

# ─── Test-accessible timer aliases (private backing vars, exposed for test arrange/assert) ──

## Remaining coyote time in seconds (Story 002 manages countdown).
var coyote_timer: float:
	get:
		return _coyote_timer
	set(value):
		_coyote_timer = value

## Remaining jump-buffer time in seconds (Story 002 manages countdown).
var jump_buffer_timer: float:
	get:
		return _jump_buffer_timer
	set(value):
		_jump_buffer_timer = value

## Remaining hit-stun time in seconds (Story 004 manages countdown).
var hit_stun_timer: float:
	get:
		return _hit_stun_timer
	set(value):
		_hit_stun_timer = value

## Remaining parry-exit time in seconds (Story 003 manages countdown).
var parry_exit_timer: float:
	get:
		return _parry_exit_timer
	set(value):
		_parry_exit_timer = value

# ─── Built-in virtual methods ─────────────────────────────────────────────────

func _ready() -> void:
	spawn_position = global_position
	EventBus.player_died.connect(_on_player_died)
	EventBus.player_hp_changed.connect(_on_player_hp_changed)


func _physics_process(delta: float) -> void:
	_handle_input()
	_process_state(delta)
	# DODGING: DodgeSystem owns position; skip move_and_slide to avoid fighting
	# the external position controller. The physics pause behavior is Story 005.
	if player_state != GameEnums.PlayerState.DODGING:
		move_and_slide()

# ─── Public methods ───────────────────────────────────────────────────────────

## Resets all stateful variables to post-death-screen initial values (ADR-0003 contract).
## Called by InstantRetrySystem during SceneTree.paused = true.
## Direct player_state assignment here is intentional — bypasses _transition_to() to
## prevent _enter_state()/_exit_state() side-effects (signal emissions) into the
## paused SceneTree. This is the documented exception from ADR-0003.
func reset_for_retry(_ctx: Dictionary) -> void:
	player_state = GameEnums.PlayerState.IDLE  # intentional direct assignment (ADR-0003)
	velocity = Vector2.ZERO
	position = spawn_position
	facing_direction = 1
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	hit_stun_timer = 0.0
	parry_exit_timer = 0.0
	_prev_hp = 0.0   # reset HP baseline so first hp_changed after retry is not misread as damage


## Guard: true when the player may enter PARRYING from the current state.
func _can_parry() -> bool:
	return player_state in [
		GameEnums.PlayerState.IDLE,
		GameEnums.PlayerState.RUNNING,
		GameEnums.PlayerState.AIRBORNE,
	]


## Guard: true when the player may enter DODGING from the current state.
func _can_dodge() -> bool:
	return player_state in [
		GameEnums.PlayerState.IDLE,
		GameEnums.PlayerState.RUNNING,
	]


## Guard: true when the player may jump (grounded or within coyote window).
## Jump execution (velocity.y = -jump_impulse) is Story 002.
func _can_jump() -> bool:
	return is_on_floor() or _coyote_timer > 0.0


## Guard: true when the player may issue an attack from the current state.
func _can_attack() -> bool:
	return player_state in [
		GameEnums.PlayerState.IDLE,
		GameEnums.PlayerState.RUNNING,
		GameEnums.PlayerState.AIRBORNE,
	]


## Receives the parry animation duration from ParryTelegraphSystem.
## Starts the exit timer; _process_state(PARRYING) counts down and transitions to IDLE.
## duration must be > 0.0; zero or negative is ignored with a warning (would lock PARRYING forever).
func exit_parry_state(duration: float) -> void:
	if duration <= 0.0:
		push_warning("PlayerController: exit_parry_state called with duration %f <= 0.0; ignoring." % duration)
		return
	_parry_exit_timer = duration

# ─── Private methods ──────────────────────────────────────────────────────────

## Central state transition dispatcher. The ONLY place player_state is assigned.
## Calls _exit_state on the old state, assigns, then calls _enter_state on the new state.
func _transition_to(new_state: GameEnums.PlayerState) -> void:
	_exit_state(player_state)
	player_state = new_state
	_enter_state(new_state)


## Per-state setup logic called immediately after entering a new state.
func _enter_state(state: GameEnums.PlayerState) -> void:
	match state:
		GameEnums.PlayerState.IDLE:
			pass
		GameEnums.PlayerState.RUNNING:
			pass
		GameEnums.PlayerState.AIRBORNE:
			pass
		GameEnums.PlayerState.PARRYING:
			velocity.x = 0.0
			parry_input_pressed.emit()
		GameEnums.PlayerState.DODGING:
			pass
		GameEnums.PlayerState.HIT_STUN:
			_hit_stun_timer = _hit_stun_duration
			velocity.x = -float(facing_direction) * knockback_speed
		GameEnums.PlayerState.DEAD:
			velocity = Vector2.ZERO


## Per-state teardown logic called immediately before leaving a state.
func _exit_state(state: GameEnums.PlayerState) -> void:
	match state:
		GameEnums.PlayerState.IDLE:
			if not _jumped_this_frame and _coyote_timer <= 0.0:
				_coyote_timer = coyote_time_duration
		GameEnums.PlayerState.RUNNING:
			if not _jumped_this_frame and _coyote_timer <= 0.0:
				_coyote_timer = coyote_time_duration
		GameEnums.PlayerState.AIRBORNE:
			pass
		GameEnums.PlayerState.PARRYING:
			_parry_exit_timer = 0.0
		GameEnums.PlayerState.DODGING:
			pass
		GameEnums.PlayerState.HIT_STUN:
			_hit_stun_timer = 0.0
		GameEnums.PlayerState.DEAD:
			pass


## Resolve input priority for this physics frame. Uses early returns to enforce
## the strict priority order: DEAD → parry → dodge → jump → attack → move.
## All input actions use StringName (&"…") form — no hardcoded key codes.
func _handle_input() -> void:
	_jumped_this_frame = false

	# Guard: DEAD state blocks all input.
	if player_state == GameEnums.PlayerState.DEAD:
		return

	# Read horizontal axis once — used by dodge direction and movement priority below.
	var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))

	# Priority 1: parry (allowed from IDLE / RUNNING / AIRBORNE).
	if Input.is_action_just_pressed(&"parry") and _can_parry():
		_transition_to(GameEnums.PlayerState.PARRYING)
		return

	# Priority 2: dodge (allowed from IDLE / RUNNING only).
	# Use current move direction for dodge direction; fall back to facing_direction if neutral.
	if Input.is_action_just_pressed(&"dodge") and _can_dodge():
		var dodge_dir: int = move_dir if move_dir != 0 else facing_direction
		_transition_to(GameEnums.PlayerState.DODGING)
		dodge_input_pressed.emit(dodge_dir)   # emit AFTER transition (state already set)
		return

	# Priority 3: jump — always prime buffer; execute immediately if _can_jump().
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_duration   # always prime buffer
		if _can_jump():
			velocity.y = -jump_impulse
			_coyote_timer = 0.0
			_jumped_this_frame = true
			_transition_to(GameEnums.PlayerState.AIRBORNE)
			return

	# Priority 4: attack (no state change; pure signal forwarding — CounterAttackComboSystem consumes).
	if Input.is_action_just_pressed(&"attack") and _can_attack():
		attack_input_pressed.emit()

	# Priority 5: horizontal movement.
	# facing_direction updates from input EXCEPT during PARRYING / DODGING / HIT_STUN.
	if move_dir != 0 and player_state not in [
		GameEnums.PlayerState.PARRYING,
		GameEnums.PlayerState.DODGING,
		GameEnums.PlayerState.HIT_STUN,
	]:
		facing_direction = move_dir

	# Apply horizontal velocity only when the player controls their own position.
	if player_state not in [
		GameEnums.PlayerState.PARRYING,
		GameEnums.PlayerState.DODGING,
		GameEnums.PlayerState.HIT_STUN,
	]:
		velocity.x = float(move_dir) * move_speed


## Per-state per-frame logic: gravity, timer countdowns, grounding checks,
## and velocity management for each state.
func _process_state(delta: float) -> void:
	if _coyote_timer > 0.0:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = maxf(0.0, _jump_buffer_timer - delta)

	match player_state:
		GameEnums.PlayerState.IDLE:
			if is_on_floor():
				velocity.y = 0.0
			else:
				_transition_to(GameEnums.PlayerState.AIRBORNE)

		GameEnums.PlayerState.RUNNING:
			if is_on_floor():
				velocity.y = 0.0
			else:
				_transition_to(GameEnums.PlayerState.AIRBORNE)

		GameEnums.PlayerState.AIRBORNE:
			# Accumulate gravity; clamp to terminal_velocity.
			velocity.y = minf(velocity.y + gravity * delta, terminal_velocity)
			# Ground detection: consume jump buffer or land normally.
			if is_on_floor():
				if _jump_buffer_timer > 0.0:
					_jump_buffer_timer = 0.0
					_jumped_this_frame = true
					velocity.y = -jump_impulse
					# NOTE for Story 005: this self-transition (AIRBORNE→AIRBORNE) is harmless
					# now but will restart _enter_state(AIRBORNE) animations when wired.
					# Before Story 005, replace _transition_to() here with a direct
					# velocity.y assignment only — no state change needed since state is already AIRBORNE.
					_transition_to(GameEnums.PlayerState.AIRBORNE)
				else:
					velocity.y = 0.0
					var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))
					if move_dir != 0:
						_transition_to(GameEnums.PlayerState.RUNNING)
					else:
						_transition_to(GameEnums.PlayerState.IDLE)

		GameEnums.PlayerState.PARRYING:
			velocity.x = 0.0
			if _parry_exit_timer > 0.0:
				_parry_exit_timer = maxf(0.0, _parry_exit_timer - delta)
				if _parry_exit_timer <= 0.0:
					# Transition to RUNNING if move input held, else IDLE.
					var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))
					if move_dir != 0:
						_transition_to(GameEnums.PlayerState.RUNNING)
					else:
						_transition_to(GameEnums.PlayerState.IDLE)

		GameEnums.PlayerState.HIT_STUN:
			# Re-lock horizontal velocity to knockback value each frame so nothing
			# can override it during the stun.
			velocity.x = -float(facing_direction) * knockback_speed
			_hit_stun_timer = maxf(0.0, _hit_stun_timer - delta)
			if _hit_stun_timer <= 0.0:
				var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))
				if move_dir != 0:
					_transition_to(GameEnums.PlayerState.RUNNING)
				else:
					_transition_to(GameEnums.PlayerState.IDLE)

		GameEnums.PlayerState.DODGING:
			# DodgeSystem owns position during dodge; skip velocity update.
			# Physics pause behavior is Story 005.
			pass

		GameEnums.PlayerState.DEAD:
			velocity = Vector2.ZERO

# ─── Signal callbacks ────────────────────────────────────────────────────────

## EventBus.player_died callback — transitions to DEAD immediately from any state.
func _on_player_died() -> void:
	_transition_to(GameEnums.PlayerState.DEAD)


## EventBus.player_hp_changed callback.
## Enters HIT_STUN when HP decreases and the player is not already DEAD.
## Always updates _prev_hp so the next comparison uses the current baseline.
func _on_player_hp_changed(current: float, _max_hp: float) -> void:
	if current < _prev_hp and player_state != GameEnums.PlayerState.DEAD:
		_transition_to(GameEnums.PlayerState.HIT_STUN)
	_prev_hp = current


## DodgeSystem.dodge_ended callback — connected by GameRoot in scene setup.
## Guard on DODGING prevents re-transition if player_died already moved to DEAD.
func _on_dodge_ended() -> void:
	if player_state != GameEnums.PlayerState.DODGING:
		return
	var move_dir: int = int(Input.get_axis(&"move_left", &"move_right"))
	if move_dir != 0:
		_transition_to(GameEnums.PlayerState.RUNNING)
	else:
		_transition_to(GameEnums.PlayerState.IDLE)
