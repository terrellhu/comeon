# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0001 (signals), ADR-0002 (BossData injection), ADR-0003 (reset_for_retry)
# THE sole owner of HP mutation. No other module may directly write HP.

class_name HealthDamageSystem
extends Node

@export var player_max_hp: float = 100.0
@export var player_hp_segments: int = 5
@export var player_hit_invuln_duration: float = 0.5

var current_player_hp: float = 100.0
var current_boss_hp: float = 1000.0
var boss_max_hp: float = 1000.0
var phase_threshold_pct: Array[float] = []

var invuln_timer: float = 0.0
var _entered_phases: Dictionary = {}   ## key: threshold_pct (float), value: true
var _boss_defeated: bool = false

func initialize(boss_data: BossData) -> void:
	boss_max_hp = boss_data.boss_max_hp
	phase_threshold_pct = boss_data.phase_threshold_pct.duplicate()

	if not RetryContext.is_fresh_start():
		var ctx := RetryContext.load_context()
		current_boss_hp = ctx["boss_hp"]
		# Mark which phase thresholds have already been crossed
		for pct in phase_threshold_pct:
			if current_boss_hp / boss_max_hp <= pct:
				_entered_phases[pct] = true
	else:
		current_boss_hp = boss_max_hp

	current_player_hp = player_max_hp
	EventBus.player_hp_changed.emit(current_player_hp, player_max_hp)
	EventBus.boss_hp_changed.emit(current_boss_hp, boss_max_hp, get_current_phase())

func _physics_process(delta: float) -> void:
	if invuln_timer > 0.0:
		invuln_timer = maxf(invuln_timer - delta, 0.0)

func apply_damage(target: GameEnums.Target, amount: float) -> void:
	if amount <= 0.0:
		return
	match target:
		GameEnums.Target.PLAYER:
			if invuln_timer > 0.0:
				return
			current_player_hp = maxf(current_player_hp - amount, 0.0)
			invuln_timer = player_hit_invuln_duration
			HitpauseManager.trigger_hitpause(0.060)
			EventBus.player_hp_changed.emit(current_player_hp, player_max_hp)
			if current_player_hp <= 0.0:
				EventBus.player_died.emit()
		GameEnums.Target.BOSS:
			if _boss_defeated:
				return
			current_boss_hp = maxf(current_boss_hp - amount, 0.0)
			_check_phase_transitions()
			EventBus.boss_hp_changed.emit(current_boss_hp, boss_max_hp, get_current_phase())
			if current_boss_hp <= 0.0 and not _boss_defeated:
				_boss_defeated = true
				EventBus.boss_defeated.emit()

func apply_healing(target: GameEnums.Target, amount: float) -> void:
	if amount <= 0.0 or target != GameEnums.Target.PLAYER:
		return
	current_player_hp = minf(current_player_hp + amount, player_max_hp)
	EventBus.player_hp_changed.emit(current_player_hp, player_max_hp)

func get_current_phase() -> int:
	var phase := 1
	for pct in phase_threshold_pct:
		if _entered_phases.get(pct, false):
			phase += 1
	return phase

## ADR-0003 reset contract
func reset_for_retry(ctx: Dictionary) -> void:
	current_player_hp = player_max_hp
	current_boss_hp = ctx["boss_hp"]
	invuln_timer = 0.0
	_boss_defeated = false
	# Do NOT clear _entered_phases — phase transitions persist across retry
	EventBus.player_hp_changed.emit(current_player_hp, player_max_hp)
	EventBus.boss_hp_changed.emit(current_boss_hp, boss_max_hp, get_current_phase())

func _check_phase_transitions() -> void:
	for i in range(phase_threshold_pct.size()):
		var pct: float = phase_threshold_pct[i]
		if not _entered_phases.get(pct, false):
			if current_boss_hp / boss_max_hp <= pct:
				_entered_phases[pct] = true
				EventBus.boss_phase_changed.emit(i + 1, i + 2)
