# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does the parry-counter mastery loop survive full architectural design at near-production quality?
# Date: 2026-06-01
#
# Single source of truth for all shared enums across the VS.
# Production: keep in scripts/data/game_enums.gd — source: ADR-0002

class_name GameEnums

enum AttackType {
	LIGHT,  ## 0.8s telegraph, 0.30s window, 1.0s stagger
	HEAVY,  ## 1.2s telegraph, 0.35s window, 1.5s stagger
	SWEEP,  ## 1.5s telegraph, 0.45s window, 2.0s stagger
}

enum ComboState {
	IDLE,
	COUNTER_WINDOW_OPEN,
	BONUS_STAGGER,
}

enum Target {
	PLAYER,
	BOSS,
}

enum PlayerState {
	IDLE,
	RUNNING,
	AIRBORNE,
	PARRYING,
	DODGING,    ## VS-tier (placeholder, not fully implemented in VS)
	HIT_STUN,
	DEAD,
}
