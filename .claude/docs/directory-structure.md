# Directory Structure

```text
/
├── CLAUDE.md                    # Master configuration
├── .claude/                     # Agent definitions, skills, hooks, rules, docs
├── design/                      # Game design documents (gdd, narrative, levels, balance)
├── docs/                        # Technical documentation (architecture, api, postmortems)
│   └── engine-reference/        # Curated engine API snapshots (version-pinned)
├── prototypes/                  # Throwaway prototypes (isolated from game/)
├── production/                  # Production management (sprints, milestones, releases)
│   ├── session-state/           # Ephemeral session state (active.md — gitignored)
│   └── session-logs/            # Session audit trail (gitignored)
└── game/                        # Godot 4.6 project root (res:// maps here)
    ├── project.godot
    ├── addons/                  # GUT and other approved addons
    ├── autoloads/               # Autoload singletons (EventBus, RetryContext, HitpauseManager)
    ├── scripts/                 # Game source code (data/, foundation/, core/, feature/, ui/)
    ├── assets/                  # Game assets (art, audio, vfx, shaders, data)
    ├── scenes/                  # .tscn scene files
    └── tests/                   # Test suites (unit/, integration/, performance/)
```

> **Note**: All Godot `res://` paths are relative to `game/`.
> Story files and CI commands reference paths as `game/scripts/...` from the repo root.
> Run the Godot editor and headless commands with `--path C:\game\comeon\game`.
