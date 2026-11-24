# Stack & Ride — notes for Claude

Roguelite delivery game (board-game style) built with Godot 4.7, typed GDScript.
The owner writes Java at work and is new to game development: explain Godot-specific choices briefly.
Talk to the owner in French.

## Game rules

- `docs/game-design.md` is the source of truth for every rule and number (bag, cards, offers,
  deliveries, rating, rent, shop, profiles, events). Read the relevant sections before porting a rule.
- `docs/prototype/dernier-kilometre.html` is the playable HTML prototype the rules come from
  (open it in a browser; its JavaScript shows the exact behaviour). If it disagrees with the
  design doc, the design doc wins: point out the discrepancy to the owner.
- Numbers are a first, unbalanced draft: keep them in data or named constants, never inline.

## Conventions

- Code, identifiers and code comments in English. Player-facing text in French, never hard-coded:
  add a key to `i18n/fr.po` and use `tr("KEY")`.
- Static typing everywhere (`var x: int`, `-> void`). Tabs for indentation.
- `core/` holds the game rules. It must not depend on nodes, scenes or anything under `ui/`.
  Core classes extend `RefCounted` (or `Resource` for data), take a `GameRng` for every random
  choice, and never call the global `randi()`/`randf()`.
- Every action of `Game` that changes the state is recorded in `state.actions` (`_log()`): a save is the seed plus
  these actions, loaded by playing them again (`core/save/run_save.gd`). A new action must be logged and replayed
  there; the state must only change through `Game` actions and the seeded `GameRng`, or saves break.
- `data/` holds game content as `.tres` resources (dishes, cards, restaurants…), so adding
  content does not need code.
- `ui/` reads the state and sends actions to the core; it never mutates the state directly.
  Views emit signals, `ui/game/game_screen.gd` calls the matching `Game` action, reports a refusal
  in the feed and refreshes every view. To grey out a button, ask the core (`card_problem()`,
  `offer_problem()`, `move_problem()`...) instead of repeating a rule in the UI.
  Shared look in `ui/style/ui_style.gd` (theme, colors), texts built in `ui/game/ui_text.gd`.
  The game screen is a board: the map fills the screen, the rest floats over it (top bar, hand and
  buttons at the bottom, windows of the app / bag / history, snack bar `ui/style/toast.gd`, help
  bubbles `ui/style/help_bubble.gd`). Phones are held upright: `ui/device.gd` (interface scale,
  narrow screens, touch). Hover does not exist on a phone: anything shown on hover needs a touch
  equivalent (first touch shows, second acts).
  Menus and option windows are in `ui/menus/`; options and helps already seen in `ui/settings.gd` (static, file only
  once `Settings.use_file()` is called). The game screen saves and resumes the run only when `save_path` is set
  (its `_ready()` does it): the tests never touch the player's save or settings.
  Animations (`ui/style/motion.gd`, tweens) and sounds (`ui/sfx.gd`, `assets/sounds/`) only show the
  state, never change it, and do nothing outside the scene tree (the tests). No autoloads: they do not
  exist when the tests run with `--script`.
- `sim/` holds headless simulations (bots) used for balancing, and the report of the runs played by people
  (`scripts/run_playtests.sh`, runs kept by the game in `user://runs`).

## Tests

- Every core rule gets tests in `tests/`, in files named `test_*.gd` extending `TestCase`
  (see `tests/test_case.gd`). Test methods start with `test_`.
- Run them with `scripts/run_tests.sh` (or `scripts\run_tests.ps1` on Windows).
- `tests/ui/` checks that every translation key used by the UI exists and plays a whole run
  through the game screen (without drawing).

## Workflow

- One branch per iteration (`iteration-N`), merged into `main` by the owner after review.
- The MVP plan and iteration list live in `docs/mvp-plan.md`; update the iteration status there.
