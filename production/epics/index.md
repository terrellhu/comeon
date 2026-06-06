# Epics Index

Last Updated: 2026-06-04 (Feature layer added)
Engine: Godot 4.6

## Foundation Layer

| Epic | Layer | System / Module | GDD | Stories | Status |
|------|-------|-----------------|-----|---------|--------|
| [signal-infrastructure](signal-infrastructure/EPIC.md) | Foundation | EventBus + GameEnums | N/A (infrastructure) | 3 stories | Ready |
| [bossdata-resource-architecture](bossdata-resource-architecture/EPIC.md) | Foundation | BossData Resources + BossDataLoader | boss-state-machine.md | 3 stories | Ready |
| [retry-context](retry-context/EPIC.md) | Foundation | RetryContext + HitpauseManager Autoloads | instant-retry-system.md | 2 stories | Ready |

## Core Layer

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| [health-damage-system](health-damage-system/EPIC.md) | Core | HealthDamageSystem | health-damage-system.md | 7 stories | Ready |
| [player-controller](player-controller/EPIC.md) | Core | PlayerController | player-controller-system.md | 6 stories | Ready |

## Feature Layer

| Epic | Layer | System | GDD | Stories | Status |
|---|---|---|---|---|---|
| [boss-state-machine](boss-state-machine/EPIC.md) | Feature | BossStateMachine | boss-state-machine.md | 5 stories | Ready ✅ |
| [parry-telegraph-system](parry-telegraph-system/EPIC.md) | Feature | ParryTelegraphSystem | parry-telegraph-system.md | TBD — run `/create-stories parry-telegraph-system` | Ready ⚠️ GAP-02 |
| [counter-attack-combo](counter-attack-combo/EPIC.md) | Feature | CounterAttackComboSystem | counter-attack-combo.md | TBD — run `/create-stories counter-attack-combo` | Ready ⚠️ GAP-02 |
| [instant-retry-system](instant-retry-system/EPIC.md) | Feature | InstantRetrySystem | instant-retry-system.md | TBD — run `/create-stories instant-retry-system` | ❌ BLOCKED (CONFLICT-01) |

## Presentation Layer

| Epic | Layer | System | GDD | Stories | Status |
|---|---|---|---|---|---|
| hud-system | Presentation | HUDSystem | hud-system.md | TBD — run `/create-epics layer:presentation` | Not yet created |

---

## Implementation Order (Sprint 002)

Dependency-safe order for Feature layer:

1. **Resolve CONFLICT-01** (S002-I01) → unblocks instant-retry-system
2. **Resolve GAP-02** (S002-I02) → unblocks parry-telegraph-system and counter-attack-combo parameter stories
3. **boss-state-machine** — no blockers (ADR-0001/0002/0004/0005 all Accepted, 12/12 TRs covered)
4. **parry-telegraph-system** — after GAP-02
5. **counter-attack-combo** — after parry-telegraph-system
6. **instant-retry-system** — after CONFLICT-01 + all other Feature systems

## Implementation Order (Foundation)

Build in dependency order — each unblocks the next:

1. **signal-infrastructure** — EventBus + GameEnums (no dependencies; blocks everything)
2. **bossdata-resource-architecture** — depends on GameEnums from #1
3. **retry-context** — depends on EventBus (#1); reset_for_retry contract consumed by Core/Feature epics

All three governed by Accepted ADRs (ADR-0001/0002/0003/0005). One partial-traced
requirement (TR-PTS-011) has a Control Manifest default — not blocking.
