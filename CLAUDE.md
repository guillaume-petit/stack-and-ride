# Stack & Ride — notes for Claude

Roguelite delivery game (board-game style) built with Godot 4.7, typed GDScript.
The owner writes Java at work and is new to game development: explain Godot-specific choices briefly.
Talk to the owner in French.

## Conventions

- Code, identifiers and code comments in English. Player-facing text in French, never hard-coded:
  add a key to `i18n/fr.po` and use `tr("KEY")`.
- Static typing everywhere (`var x: int`, `-> void`). Tabs for indentation.
- `core/` holds the game rules. It must not depend on nodes, scenes or anything under `ui/`.
  Core classes extend `RefCounted` (or `Resource` for data), take a `GameRng` for every random
  choice, and never call the global `randi()`/`randf()`.
- `data/` holds game content as `.tres` resources (dishes, cards, restaurants…), so adding
  content does not need code.
- `ui/` reads the state and sends actions to the core; it never mutates the state directly.
- `sim/` holds headless simulations (bots) used for balancing.

## Tests

- Every core rule gets tests in `tests/`, in files named `test_*.gd` extending `TestCase`
  (see `tests/test_case.gd`). Test methods start with `test_`.
- Run them with `scripts/run_tests.sh` (or `scripts\run_tests.ps1` on Windows).

## Workflow

- One branch per iteration (`iteration-N`), merged into `main` by the owner after review.
- The MVP plan and iteration list live in `docs/mvp-plan.md`; update the iteration status there.
