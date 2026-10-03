# Convey

Convey is an original learning game. It is inspired by the public conveyor color-clear idea: colored cells, shooters with ammo, a moving conveyor, and a few waiting slots. It is not affiliated with any store game. The name, levels, colors, and sound are original. Cells are rectangles. Shooters are circles. There is no timer, no lives, no ads, no purchases, and no account.

## Rules

- The board is a small grid, at most 6 by 6. In `Levels.json`, the first row is the top. The conveyor runs along the bottom.
- A cell can be cleared only when it is the lowest colored cell in its column, so it is adjacent to the conveyor or to the gap above it.
- Tap a shooter. It rides the conveyor from left to right. Each time it is adjacent to one cell of its color, it clears that cell and spends one ammo. The number on the shooter is its ammo.
- If ammo hits zero, the shooter leaves.
- If ammo is left when the ride ends, the shooter waits in a slot. There are 5 slots. A shooter that still needs a slot when all five are full fails the level.
- The conveyor holds 5 shooters. Sending another one fails the level. A shooter that is mid-ride still occupies a spot.
- Clear every colored cell to win. Restart plays the level again. Next, after a win, loads the following level. After level 8, Next returns to level 1.

## Open and run

1. Open `Convey.xcodeproj` in Xcode on a Mac.
2. Select the Convey target, open Signing & Capabilities, and pick your Team. The project uses automatic signing and does not set a development team.
3. Choose your iPhone as the run destination. The app is portrait only and targets iOS 16 or later.
4. Press Run.

## Check the levels

Eight hand-authored levels live in `Convey/Levels.json`. `Board.swift` applies the rules and does not import SpriteKit. `tools/solve_levels.py` uses those same rules and searches for a win.

```bash
python3 tools/solve_levels.py
```

It prints a solution length for each level. A length is the number of taps in one winning line.

## Sound

`tools/gen_clear_wav.py` writes a short original pop. The app bundles `Convey/clear.wav.b64` (the wav bytes) and plays it when a cell clears. The script also writes `build/clear.wav` if you want to listen on a computer.

```bash
python3 tools/gen_clear_wav.py
```

## Project layout

- `Level.swift` loads the level data.
- `Board.swift` is the rules.
- `GameScene.swift` draws the board and handles taps.
