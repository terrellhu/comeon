# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
# source: ADR-0002 — validates BossData on load

class_name BossDataLoader
extends Node

func get_boss_data(boss_id: StringName) -> BossData:
	var path := "res://data/bosses/%s.tres" % boss_id
	if ResourceLoader.exists(path):
		var data := ResourceLoader.load(path) as BossData
		assert(data != null, "BossData at %s is not a BossData resource" % path)
		_validate(data)
		return data
	push_warning("BossDataLoader: no .tres at %s — using factory fallback" % path)
	return null

## GUT tests and VS bootstrap use this to create BossData without .tres files.
func make_test_data() -> BossData:
	return _build_boss_01()

static func _build_boss_01() -> BossData:
	# Phase 1 sequence
	var p1_attacks: Array[AttackData] = []
	for spec in [
		[GameEnums.AttackType.LIGHT, 10.0, 0.0, 0.5],
		[GameEnums.AttackType.HEAVY, 20.0, 0.0, 0.8],
		[GameEnums.AttackType.SWEEP, 15.0, 0.0, 1.0],
		[GameEnums.AttackType.LIGHT, 10.0, 0.0, 0.5],
		[GameEnums.AttackType.HEAVY, 20.0, 0.0, 0.8],
	]:
		var a := AttackData.new()
		a.attack_type = spec[0]
		a.damage = spec[1]
		a.telegraph_duration_override = spec[2]
		a.attack_anim_duration = spec[3]
		p1_attacks.append(a)

	var phase1 := PhaseData.new()
	phase1.phase_index = 0
	phase1.attack_sequence = p1_attacks
	phase1.idle_duration_after_attack = 0.5
	phase1.phase_transition_anim = &""

	# Phase 2 sequence (faster, no LIGHT breathing room)
	var p2_attacks: Array[AttackData] = []
	for spec in [
		[GameEnums.AttackType.HEAVY, 25.0, 1.0, 0.7],   # override: faster heavy
		[GameEnums.AttackType.SWEEP, 20.0, 0.0, 1.0],
		[GameEnums.AttackType.HEAVY, 25.0, 0.0, 0.8],
	]:
		var a := AttackData.new()
		a.attack_type = spec[0]
		a.damage = spec[1]
		a.telegraph_duration_override = spec[2]
		a.attack_anim_duration = spec[3]
		p2_attacks.append(a)

	var phase2 := PhaseData.new()
	phase2.phase_index = 1
	phase2.attack_sequence = p2_attacks
	phase2.idle_duration_after_attack = 0.3   # faster pace
	phase2.phase_transition_anim = &"phase_transition"

	var boss := BossData.new()
	boss.boss_id = &"boss_01"
	boss.boss_max_hp = 1000.0
	boss.phase_threshold_pct = [0.6]   # one transition: 60% HP triggers Phase 2
	boss.phases = [phase1, phase2]
	return boss

func _validate(data: BossData) -> void:
	assert(data.boss_id != &"", "BossData.boss_id must not be empty")
	assert(data.boss_max_hp > 0.0, "BossData.boss_max_hp must be > 0")
	assert(data.phases.size() > 0, "BossData.phases must not be empty")
	# Validate descending phase_threshold_pct order
	for i in range(data.phase_threshold_pct.size() - 1):
		assert(data.phase_threshold_pct[i] > data.phase_threshold_pct[i + 1],
			"phase_threshold_pct must be in descending order")
	for phase in data.phases:
		assert(phase.attack_sequence.size() > 0,
			"PhaseData[%d].attack_sequence must not be empty" % phase.phase_index)
		if phase.idle_duration_after_attack < 0.1:
			push_warning("idle_duration_after_attack < 0.1s clamped to 0.1s (phase %d)" % phase.phase_index)
			phase.idle_duration_after_attack = 0.1
		for attack in phase.attack_sequence:
			if attack.telegraph_duration_override > 0.0 and attack.telegraph_duration_override < 0.1:
				push_warning("telegraph_duration_override < 0.1s clamped to 0.1s")
				attack.telegraph_duration_override = 0.1
