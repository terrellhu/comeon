# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the parry timing window feel satisfying enough that players voluntarily retry 3+ times?
# Date: 2026-05-31

extends Node2D

# === TWEAK THESE TO TEST FEEL ===
# Increase PARRY_WINDOW_SIZE to make parrying easier; decrease to make it harder.
const TELEGRAPH_DURATION: float = 1.0    # Total wind-up time (seconds) before attack lands
const PARRY_WINDOW_START: float = 0.50   # Window opens at this fraction of telegraph (0.0-1.0)
const PARRY_WINDOW_END: float = 0.85     # Window closes at this fraction of telegraph
const COUNTER_DURATION: float = 0.5     # How long the counter-attack flash lasts
const RESET_DELAY: float = 1.5          # Pause before next attack cycle
# ================================

enum Phase { IDLE, TELEGRAPH, ATTACK, PARRY_SUCCESS, PARRY_FAIL, COUNTER, RESET_WAIT }
var phase: Phase = Phase.IDLE
var phase_timer: float = 0.0
var parry_window_open: bool = false
var parry_attempted: bool = false

# Stats
var parry_count: int = 0
var attempt_count: int = 0

# Nodes (created in _ready)
var player_rect: ColorRect
var boss_rect: ColorRect
var status_lbl: Label
var hint_lbl: Label
var stats_lbl: Label
var window_bar_bg: ColorRect
var window_bar_fill: ColorRect
var window_marker_start: ColorRect
var window_marker_end: ColorRect
var big_prompt: Label


func _ready() -> void:
	_build_scene()
	_start_idle()


func _build_scene() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.size = Vector2(800, 500)
	bg.color = Color(0.08, 0.08, 0.12)
	add_child(bg)

	# Player rectangle (left side)
	player_rect = ColorRect.new()
	player_rect.size = Vector2(60, 90)
	player_rect.position = Vector2(160, 195)
	player_rect.color = Color(0.2, 0.45, 0.9)
	add_child(player_rect)

	# Boss rectangle (right side)
	boss_rect = ColorRect.new()
	boss_rect.size = Vector2(110, 110)
	boss_rect.position = Vector2(570, 185)
	boss_rect.color = Color(0.55, 0.08, 0.08)
	add_child(boss_rect)

	# --- Telegraph progress bar (shows timing visually) ---
	# Background track
	window_bar_bg = ColorRect.new()
	window_bar_bg.size = Vector2(760, 18)
	window_bar_bg.position = Vector2(20, 370)
	window_bar_bg.color = Color(0.15, 0.15, 0.15)
	add_child(window_bar_bg)

	# Fill bar (red → orange in window)
	window_bar_fill = ColorRect.new()
	window_bar_fill.size = Vector2(0, 18)
	window_bar_fill.position = Vector2(20, 370)
	window_bar_fill.color = Color(0.5, 0.08, 0.08)
	add_child(window_bar_fill)

	# Window start marker (white vertical line)
	window_marker_start = ColorRect.new()
	window_marker_start.size = Vector2(3, 24)
	window_marker_start.position = Vector2(20 + PARRY_WINDOW_START * 760, 367)
	window_marker_start.color = Color(1.0, 0.7, 0.0, 0.8)
	add_child(window_marker_start)

	# Window end marker
	window_marker_end = ColorRect.new()
	window_marker_end.size = Vector2(3, 24)
	window_marker_end.position = Vector2(20 + PARRY_WINDOW_END * 760, 367)
	window_marker_end.color = Color(1.0, 0.3, 0.0, 0.8)
	add_child(window_marker_end)

	# Big center prompt (shown only during window)
	big_prompt = Label.new()
	big_prompt.position = Vector2(400, 170)
	big_prompt.add_theme_font_size_override("font_size", 36)
	big_prompt.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	big_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_prompt.text = ""
	big_prompt.visible = false
	add_child(big_prompt)

	# Stats (top-left)
	stats_lbl = Label.new()
	stats_lbl.position = Vector2(20, 12)
	stats_lbl.add_theme_font_size_override("font_size", 16)
	stats_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	stats_lbl.text = "Parries: 0  |  Attempts: 0"
	add_child(stats_lbl)

	# State label (bottom)
	status_lbl = Label.new()
	status_lbl.position = Vector2(20, 400)
	status_lbl.add_theme_font_size_override("font_size", 18)
	add_child(status_lbl)

	# Hint label
	hint_lbl = Label.new()
	hint_lbl.position = Vector2(20, 430)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hint_lbl.text = "Press SPACE (or J on gamepad) when the boss flashes orange — timing bar shows the window"
	add_child(hint_lbl)

	# Tweak reminder
	var tweak_lbl := Label.new()
	tweak_lbl.position = Vector2(20, 460)
	tweak_lbl.add_theme_font_size_override("font_size", 11)
	tweak_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	tweak_lbl.text = "Adjust PARRY_WINDOW_START / PARRY_WINDOW_END in main.gd to tune feel"
	add_child(tweak_lbl)


func _process(delta: float) -> void:
	phase_timer += delta

	match phase:
		Phase.IDLE:
			if phase_timer >= 1.2:
				_start_telegraph()
		Phase.TELEGRAPH:
			_update_telegraph()
		Phase.ATTACK:
			if phase_timer >= 0.18:
				_on_hit()
		Phase.PARRY_SUCCESS:
			if phase_timer >= 0.28:
				_start_counter()
		Phase.COUNTER:
			if phase_timer >= COUNTER_DURATION:
				_start_reset()
		Phase.PARRY_FAIL:
			if phase_timer >= RESET_DELAY:
				_start_idle()
		Phase.RESET_WAIT:
			if phase_timer >= RESET_DELAY:
				_start_idle()


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if key != KEY_SPACE and key != KEY_J:
		return

	match phase:
		Phase.TELEGRAPH:
			if parry_window_open and not parry_attempted:
				parry_attempted = true
				parry_count += 1
				attempt_count += 1
				_update_stats()
				_on_parry_success()
			elif not parry_window_open and phase_timer / TELEGRAPH_DURATION < PARRY_WINDOW_START:
				status_lbl.text = "Too early — wait for the orange glow!"
				status_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 0.1))
		Phase.ATTACK, Phase.PARRY_FAIL:
			status_lbl.text = "Too late!"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _update_telegraph() -> void:
	var progress: float = phase_timer / TELEGRAPH_DURATION

	# Update timing bar fill
	window_bar_fill.size.x = progress * 760.0

	if progress < PARRY_WINDOW_START:
		# Pre-window: dark red → warm red ramp
		var t: float = progress / PARRY_WINDOW_START
		boss_rect.color = Color(0.55 + t * 0.25, 0.08, 0.05)
		window_bar_fill.color = Color(0.5 + t * 0.2, 0.08, 0.08)
		parry_window_open = false
		big_prompt.visible = false
		if status_lbl.text != "Preparing...":
			status_lbl.text = "Preparing..."
			status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	elif progress < PARRY_WINDOW_END:
		# Window open: bright orange flash — PARRY NOW
		var t: float = (progress - PARRY_WINDOW_START) / (PARRY_WINDOW_END - PARRY_WINDOW_START)
		var pulse: float = 0.5 + 0.5 * sin(t * TAU * 2.0)  # pulse twice during window
		boss_rect.color = Color(1.0, 0.45 + pulse * 0.35, 0.0)
		window_bar_fill.color = Color(1.0, 0.5 + pulse * 0.2, 0.0)
		parry_window_open = true
		if not parry_attempted:
			big_prompt.text = "PARRY!"
			big_prompt.visible = true
			status_lbl.text = ">>> Press SPACE now! <<<"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))

	else:
		# Window closed — too late
		parry_window_open = false
		big_prompt.visible = false
		boss_rect.color = Color(0.85, 0.05, 0.05)
		window_bar_fill.color = Color(0.85, 0.05, 0.05)
		if not parry_attempted:
			status_lbl.text = "Window closed — attack incoming!"
			status_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))

	# Telegraph finished — attack fires
	if progress >= 1.0 and not parry_attempted:
		attempt_count += 1
		_update_stats()
		_start_attack()


func _start_idle() -> void:
	phase = Phase.IDLE
	phase_timer = 0.0
	player_rect.color = Color(0.2, 0.45, 0.9)
	boss_rect.color = Color(0.55, 0.08, 0.08)
	window_bar_fill.size.x = 0.0
	window_bar_fill.color = Color(0.5, 0.08, 0.08)
	big_prompt.visible = false
	status_lbl.text = "Ready..."
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _start_telegraph() -> void:
	phase = Phase.TELEGRAPH
	phase_timer = 0.0
	parry_window_open = false
	parry_attempted = false
	boss_rect.color = Color(0.55, 0.08, 0.08)
	player_rect.color = Color(0.2, 0.45, 0.9)
	window_bar_fill.size.x = 0.0


func _start_attack() -> void:
	phase = Phase.ATTACK
	phase_timer = 0.0
	boss_rect.color = Color(1.0, 0.0, 0.0)
	big_prompt.visible = false


func _on_hit() -> void:
	phase = Phase.PARRY_FAIL
	phase_timer = 0.0
	player_rect.color = Color(0.9, 0.1, 0.1)
	boss_rect.color = Color(0.55, 0.08, 0.08)
	window_bar_fill.size.x = 0.0
	status_lbl.text = "HIT! Watch for the orange glow next time."
	status_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))


func _on_parry_success() -> void:
	phase = Phase.PARRY_SUCCESS
	phase_timer = 0.0
	player_rect.color = Color(0.1, 0.9, 0.35)
	boss_rect.color = Color(0.28, 0.28, 0.28)
	window_bar_fill.color = Color(0.1, 0.9, 0.35)
	big_prompt.text = "COUNTER!"
	big_prompt.add_theme_color_override("font_color", Color(0.1, 1.0, 0.4))
	big_prompt.visible = true
	status_lbl.text = "PARRY SUCCESS — Counter attack!"
	status_lbl.add_theme_color_override("font_color", Color(0.1, 0.9, 0.35))


func _start_counter() -> void:
	phase = Phase.COUNTER
	phase_timer = 0.0
	boss_rect.color = Color(0.9, 0.7, 0.1)  # Boss staggers yellow
	status_lbl.text = "Boss staggered!"
	status_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1))


func _start_reset() -> void:
	phase = Phase.RESET_WAIT
	phase_timer = 0.0
	player_rect.color = Color(0.2, 0.45, 0.9)
	boss_rect.color = Color(0.55, 0.08, 0.08)
	big_prompt.visible = false
	window_bar_fill.size.x = 0.0
	window_bar_fill.color = Color(0.5, 0.08, 0.08)
	status_lbl.text = "Next attack incoming..."
	status_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))


func _update_stats() -> void:
	stats_lbl.text = "Parries: %d  |  Attempts: %d" % [parry_count, attempt_count]
