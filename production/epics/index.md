# Epics Index

Last Updated: 2026-06-02
Engine: Godot 4.6

## Foundation Layer

| Epic | Layer | System / Module | GDD | Stories | Status |
|------|-------|-----------------|-----|---------|--------|
| [signal-infrastructure](signal-infrastructure/EPIC.md) | Foundation | EventBus + GameEnums | N/A (infrastructure) | Not yet created | Ready |
| [bossdata-resource-architecture](bossdata-resource-architecture/EPIC.md) | Foundation | BossData Resources + BossDataLoader | boss-state-machine.md | Not yet created | Ready |
| [retry-context](retry-context/EPIC.md) | Foundation | RetryContext + HitpauseManager Autoloads | instant-retry-system.md | Not yet created | Ready |

## Core Layer

*Not yet created — run `/create-epics layer:core` after Foundation stories are underway.*

## Feature Layer

*Not yet created — run `/create-epics layer:feature` when Core is nearly complete.*

## Presentation Layer

*Not yet created — run `/create-epics layer:presentation` when Feature is nearly complete.*

---

## Implementation Order (Foundation)

Build in dependency order — each unblocks the next:

1. **signal-infrastructure** — EventBus + GameEnums (no dependencies; blocks everything)
2. **bossdata-resource-architecture** — depends on GameEnums from #1
3. **retry-context** — depends on EventBus (#1); reset_for_retry contract consumed by Core/Feature epics

All three governed by Accepted ADRs (ADR-0001/0002/0003/0005). One partial-traced
requirement (TR-PTS-011) has a Control Manifest default — not blocking.
