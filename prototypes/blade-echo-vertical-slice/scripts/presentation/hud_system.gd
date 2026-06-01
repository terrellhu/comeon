# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0001 (pure subscriber, no signals emitted)
# HUD is on CanvasLayer. Never emits signals. Never modifies game state.

class_name HUDSystem
extends CanvasLayer

@export var player_hp_segments: int = 5
@export var player_max_hp: float = 100.0

# HP bar segments (bottom-left)
var _hp_segments: Array[ColorRect] = []
const HP_SEG_LIT   := Color(0.78, 0.75, 0.66)  ## #C8BFA8 art-bible colour
const HP_SEG_DARK  := Color(0.05, 0.04, 0.10)  ## #0D0B1A art-bible colour

# Boss HP bar (top-center)
var _boss_hp_fill: ColorRect
var _boss_hp_bg: ColorRect
var _boss_phase_labels: Array[ColorRect] = []
var _boss_max_hp: float = 1000.0
var _boss_phase_thresholds: Array[float] = []
const BOSS_BAR_W := 640.0
const BOSS_BAR_H := 14.0

# Telegraph bar (below boss HP)
var _telegraph_fill: ColorRect
var _telegraph_bg: ColorRect
const TEL_BAR_W := 640.0
const TEL_BAR_H := 6.0
const TEL_PRE_COLOR    := Color(0.55, 0.35, 0.10)
const TEL_WINDOW_COLOR := Color(0.91, 0.58, 0.10)
const TEL_POST_COLOR   := Color(0.29, 0.10, 0.06)

# Counter window bar (near player, top-left area for VS simplicity)
var _counter_bg: ColorRect
var _counter_fill: ColorRect
var _counter_label: Label
var _full_combo_label: Label
var _full_combo_timer: float = 0.0
var _current_attack_base_window: float = 1.0

# Death counter (bottom-right)
var _death_label: Label

func _ready() -> void:
	layer = 10
	_build_player_hp_bar()
	_build_boss_hp_bar()
	_build_telegraph_bar()
	_build_counter_window()
	_build_death_counter()

	EventBus.player_hp_changed.connect(_on_player_hp_changed)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.telegraph_updated.connect(_on_telegraph_updated)
	EventBus.counter_window_updated.connect(_on_counter_window_updated)
	EventBus.counter_full_combo_completed.connect(_on_full_combo_completed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.retry_death_count_changed.connect(_on_retry_death_count_changed)

func initialize(boss_data: BossData) -> void:
	_boss_max_hp = boss_data.boss_max_hp
	_boss_phase_thresholds = boss_data.phase_threshold_pct.duplicate()
	_render_boss_phase_markers()

func _process(delta: float) -> void:
	if _full_combo_timer > 0.0:
		_full_combo_timer = maxf(_full_combo_timer - delta, 0.0)
		if _full_combo_timer <= 0.0:
			_full_combo_label.visible = false

# ─── Build helpers ────────────────────────────────────────────────────────────
func _build_player_hp_bar() -> void:
	var seg_w := 28.0
	var seg_h := 12.0
	var gap := 4.0
	var base_x := 20.0
	var base_y := 680.0
	for i in range(player_hp_segments):
		var seg := ColorRect.new()
		seg.size = Vector2(seg_w, seg_h)
		seg.position = Vector2(base_x + i * (seg_w + gap), base_y)
		seg.color = HP_SEG_LIT
		add_child(seg)
		_hp_segments.append(seg)

func _build_boss_hp_bar() -> void:
	_boss_hp_bg = ColorRect.new()
	_boss_hp_bg.size = Vector2(BOSS_BAR_W, BOSS_BAR_H)
	_boss_hp_bg.position = Vector2((1280.0 - BOSS_BAR_W) / 2.0, 12.0)
	_boss_hp_bg.color = Color(0.12, 0.06, 0.06)
	add_child(_boss_hp_bg)

	_boss_hp_fill = ColorRect.new()
	_boss_hp_fill.size = Vector2(BOSS_BAR_W, BOSS_BAR_H)
	_boss_hp_fill.position = _boss_hp_bg.position
	_boss_hp_fill.color = Color(0.85, 0.34, 0.10)
	add_child(_boss_hp_fill)

func _build_telegraph_bar() -> void:
	_telegraph_bg = ColorRect.new()
	_telegraph_bg.size = Vector2(TEL_BAR_W, TEL_BAR_H)
	_telegraph_bg.position = Vector2((1280.0 - TEL_BAR_W) / 2.0, 30.0)
	_telegraph_bg.color = Color(0.08, 0.06, 0.06)
	add_child(_telegraph_bg)

	_telegraph_fill = ColorRect.new()
	_telegraph_fill.size = Vector2(0.0, TEL_BAR_H)
	_telegraph_fill.position = _telegraph_bg.position
	_telegraph_fill.color = TEL_PRE_COLOR
	add_child(_telegraph_fill)
	_telegraph_bg.visible = false
	_telegraph_fill.visible = false

func _build_counter_window() -> void:
	_counter_bg = ColorRect.new()
	_counter_bg.size = Vector2(160.0, 10.0)
	_counter_bg.position = Vector2(20.0, 650.0)
	_counter_bg.color = Color(0.08, 0.18, 0.24)
	add_child(_counter_bg)

	_counter_fill = ColorRect.new()
	_counter_fill.size = Vector2(0.0, 10.0)
	_counter_fill.position = Vector2(20.0, 650.0)
	_counter_fill.color = Color(0.54, 0.72, 0.78)
	add_child(_counter_fill)

	_counter_label = Label.new()
	_counter_label.position = Vector2(20.0, 635.0)
	_counter_label.add_theme_font_size_override("font_size", 12)
	_counter_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_counter_label.text = ""
	add_child(_counter_label)

	_full_combo_label = Label.new()
	_full_combo_label.position = Vector2(20.0, 615.0)
	_full_combo_label.add_theme_font_size_override("font_size", 18)
	_full_combo_label.add_theme_color_override("font_color", Color(0.78, 0.63, 0.13))
	_full_combo_label.text = "FULL COMBO"
	_full_combo_label.visible = false
	add_child(_full_combo_label)

	_counter_bg.visible = false
	_counter_fill.visible = false
	_counter_label.visible = false

func _build_death_counter() -> void:
	_death_label = Label.new()
	_death_label.position = Vector2(1180.0, 690.0)
	_death_label.add_theme_font_size_override("font_size", 14)
	_death_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_death_label.text = ""
	add_child(_death_label)

func _render_boss_phase_markers() -> void:
	for existing in _boss_phase_labels:
		existing.queue_free()
	_boss_phase_labels.clear()
	for pct in _boss_phase_thresholds:
		var marker := ColorRect.new()
		marker.size = Vector2(2.0, BOSS_BAR_H + 4.0)
		marker.position = _boss_hp_bg.position + Vector2(pct * BOSS_BAR_W - 1.0, -2.0)
		marker.color = Color(0.91, 0.87, 0.78)
		add_child(marker)
		_boss_phase_labels.append(marker)

# ─── Signal handlers (pure subscriber — never emit) ──────────────────────────
func _on_player_hp_changed(current: float, max_hp: float) -> void:
	var hp_per_seg := max_hp / float(player_hp_segments)
	var lit := 0 if current <= 0.0 else ceili(current / hp_per_seg)
	for i in range(player_hp_segments):
		_hp_segments[i].color = HP_SEG_LIT if i < lit else HP_SEG_DARK

func _on_boss_hp_changed(current: float, max_hp: float, _phase: int) -> void:
	if max_hp <= 0.0:
		push_warning("HUD: boss_max_hp = 0, skipping fill update")
		return
	_boss_hp_fill.size.x = clampf(current / max_hp, 0.0, 1.0) * BOSS_BAR_W

func _on_boss_phase_changed(_from: int, _to: int) -> void:
	pass  ## phase marker ticks stay static; fill colour could change here

func _on_telegraph_updated(progress: float, window_open: bool, _attack_type: GameEnums.AttackType) -> void:
	_telegraph_bg.visible = true
	_telegraph_fill.visible = true
	_telegraph_fill.size.x = clampf(progress, 0.0, 1.0) * TEL_BAR_W
	if window_open:
		_telegraph_fill.color = TEL_WINDOW_COLOR
	elif progress < 0.5:
		_telegraph_fill.color = TEL_PRE_COLOR
	else:
		_telegraph_fill.color = TEL_POST_COLOR

func _on_counter_window_updated(hit_count: int, time_remaining: float, state: GameEnums.ComboState) -> void:
	if state == GameEnums.ComboState.IDLE:
		_counter_bg.visible = false
		_counter_fill.visible = false
		_counter_label.visible = false
		return
	_counter_bg.visible = true
	_counter_fill.visible = true
	_counter_label.visible = true
	var fill_ratio := clampf(time_remaining / maxf(_current_attack_base_window, 0.001), 0.0, 1.0)
	_counter_fill.size.x = fill_ratio * 160.0
	_counter_fill.color = Color(0.78, 0.63, 0.13) if state == GameEnums.ComboState.BONUS_STAGGER else Color(0.54, 0.72, 0.78)
	_counter_label.text = "hit %d/3" % hit_count

func _on_full_combo_completed(_attack_type: GameEnums.AttackType) -> void:
	_full_combo_label.visible = true
	_full_combo_timer = 0.5

func _on_boss_defeated() -> void:
	EventBus.telegraph_updated.disconnect(_on_telegraph_updated)
	EventBus.counter_window_updated.disconnect(_on_counter_window_updated)
	_telegraph_bg.visible = false
	_telegraph_fill.visible = false
	_counter_bg.visible = false
	_counter_fill.visible = false

func _on_retry_death_count_changed(count: int) -> void:
	_death_label.text = "Deaths: %d" % count
	_telegraph_bg.visible = false
	_telegraph_fill.visible = false

func reset_for_retry(_ctx: Dictionary) -> void:
	_on_player_hp_changed(100.0, 100.0)

func set_attack_base_window(w: float) -> void:
	_current_attack_base_window = w
