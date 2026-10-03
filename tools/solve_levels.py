#!/usr/bin/env python3
"""Search every Convey level and print a winning length.

The ride matches Board.ride in Convey/Board.swift:

1. Reject the launch if the conveyor already holds beltCapacity shooters.
2. Take the shooter off the dock or out of a waiting slot.
3. Walk columns from left to right.
4. The adjacent cell in a column is the lowest colored one (closest to the belt).
5. If that cell matches and ammo remains, clear it and spend one ammo.
6. If no colored cells remain, the level is won immediately (leftover ammo does not need a slot).
7. If ammo is zero at the end of the ride, the shooter leaves.
8. If ammo remains, it must enter a waiting slot. A full tray fails the level.

Rows in Levels.json are top to bottom. The belt runs along the bottom.
The search launches one shooter at a time and lets that ride finish before the next
launch. That is a legal play (wait for the belt to clear). Queuing more is allowed
up to the belt capacity; the capacity check below is the same comparison the game uses.
"""

from __future__ import annotations

import json
import sys
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVELS_PATH = ROOT / "Convey" / "Levels.json"
LETTERS = set("ROYGBP")


def load() -> dict:
    data = json.loads(LEVELS_PATH.read_text())
    belt = data["beltCapacity"]
    slots = data["slotCapacity"]
    if belt != 5 or slots != 5:
        raise SystemExit(f"expected capacities 5 and 5, got {belt} and {slots}")
    levels = data["levels"]
    if len(levels) != 8:
        raise SystemExit(f"expected 8 levels, got {len(levels)}")
    for index, level in enumerate(levels, start=1):
        rows = level["rows"]
        if not rows or len(rows) > 6:
            raise SystemExit(f"level {index} row count out of range")
        width = len(rows[0])
        if width < 1 or width > 6:
            raise SystemExit(f"level {index} width out of range")
        for row in rows:
            if len(row) != width:
                raise SystemExit(f"level {index} is not rectangular")
            for ch in row:
                if ch != "." and ch not in LETTERS:
                    raise SystemExit(f"level {index} has unknown cell {ch}")
        if not any(ch != "." for row in rows for ch in row):
            raise SystemExit(f"level {index} has no colored cells")
        if not level["shooters"]:
            raise SystemExit(f"level {index} has no shooters")
        cells = Counter(ch for row in rows for ch in row if ch != ".")
        ammo: Counter[str] = Counter()
        for shooter in level["shooters"]:
            hue = shooter["hue"]
            count = shooter["ammo"]
            if hue not in LETTERS or count < 1:
                raise SystemExit(f"level {index} has a bad shooter")
            ammo[hue] += count
        for hue, count in cells.items():
            if ammo[hue] < count:
                raise SystemExit(f"level {index} does not have enough {hue} ammo")
    return data


def cleared(grid: tuple[str, ...]) -> bool:
    return all(ch == "." for row in grid for ch in row)


def ride(grid: tuple[str, ...], shooter: tuple[str, int], slots: tuple[tuple[str, int], ...], slot_cap: int):
    """One left-to-right ride. `slots` is the tray after this shooter has already left it."""
    hue, ammo = shooter
    board = [list(row) for row in grid]
    height = len(board)
    width = len(board[0])
    for column in range(width):
        if ammo == 0:
            break
        for row in range(height - 1, -1, -1):
            cell = board[row][column]
            if cell == ".":
                continue
            if cell == hue:
                board[row][column] = "."
                ammo -= 1
                if all(ch == "." for line in board for ch in line):
                    won = tuple("".join(line) for line in board)
                    return ("win", won)
            break
    after = tuple("".join(line) for line in board)
    if ammo == 0:
        return ("exit", after, slots)
    if len(slots) >= slot_cap:
        return ("lose-slots",)
    parked = slots + ((hue, ammo),)
    return ("park", after, parked)


def occupy(belt: list[tuple[str, int]], belt_cap: int, shooter: tuple[str, int]):
    """Same check as Board.enqueue: a 6th shooter on a belt of 5 fails."""
    if len(belt) >= belt_cap:
        return None
    belt.append(shooter)
    return belt


def prove_capacities(belt_cap: int, slot_cap: int) -> None:
    belt: list[tuple[str, int]] = []
    for _ in range(belt_cap):
        added = occupy(belt, belt_cap, ("R", 1))
        if added is None:
            raise SystemExit("belt rejected a shooter before it was full")
    if occupy(belt, belt_cap, ("R", 1)) is not None:
        raise SystemExit("belt accepted a shooter past capacity")
    print(f"conveyor: launch {belt_cap + 1} fails when {belt_cap} shooters are already on the belt")

    grid = ("G",)
    full = tuple(("R", 1) for _ in range(slot_cap))
    outcome = ride(grid, ("R", 1), full, slot_cap)
    if outcome[0] != "lose-slots":
        raise SystemExit(f"full tray did not fail, got {outcome[0]}")
    # Recycling frees a slot first, so a full tray can still relaunch.
    recycled = full[:-1]
    again = ride(grid, ("R", 1), recycled, slot_cap)
    if again[0] != "park":
        raise SystemExit("recycling from a full tray should be allowed")
    print(f"slots: parking ammo with {slot_cap} slots full fails; relaunching one of them does not")


def canon(shooters: list[tuple[str, int]] | tuple[tuple[str, int], ...]) -> tuple[tuple[str, int], ...]:
    return tuple(sorted(shooters))


def solve(level: dict, belt_cap: int, slot_cap: int) -> tuple[int, list[str]]:
    grid = tuple(level["rows"])
    dock = canon((s["hue"], s["ammo"]) for s in level["shooters"])
    slots: tuple[tuple[str, int], ...] = ()
    start = (grid, dock, slots)
    queue: deque = deque([(start, 0, [])])
    seen = {start}
    visited = 0
    while queue:
        (grid, dock, slots), dist, path = queue.popleft()
        visited += 1
        if visited > 200_000:
            raise SystemExit(f"{level['name']} exceeded the search limit")
        piles = (("dock", dock), ("slot", slots))
        for source, pile in piles:
            seen_shooter = set()
            for index, shooter in enumerate(pile):
                if shooter in seen_shooter:
                    continue
                seen_shooter.add(shooter)
                # Belt is empty between searched launches, so occupancy is 0.
                if belt_cap < 1:
                    continue
                dock_list = list(dock)
                slot_list = list(slots)
                if source == "dock":
                    dock_list.pop(index)
                else:
                    slot_list.pop(index)
                outcome = ride(grid, shooter, tuple(slot_list), slot_cap)
                label = f"{source} {shooter[0]}{shooter[1]}"
                kind = outcome[0]
                if kind == "win":
                    return dist + 1, path + [label]
                if kind == "lose-slots":
                    continue
                new_grid, new_slots = outcome[1], outcome[2]
                if new_grid == grid:
                    continue
                new_dock = canon(dock_list)
                new_slots = canon(new_slots)
                state = (new_grid, new_dock, new_slots)
                if state in seen:
                    continue
                seen.add(state)
                queue.append((state, dist + 1, path + [label]))
    raise SystemExit(f"UNWINNABLE {level['name']} ({visited} states)")


def replay(level: dict, moves: list[str], slot_cap: int) -> None:
    grid = tuple(level["rows"])
    dock = [(s["hue"], s["ammo"]) for s in level["shooters"]]
    slots: list[tuple[str, int]] = []
    for move in moves:
        source, token = move.split()
        hue, ammo = token[0], int(token[1:])
        pile = dock if source == "dock" else slots
        pile.pop(pile.index((hue, ammo)))
        outcome = ride(grid, (hue, ammo), tuple(slots), slot_cap)
        if outcome[0] == "win":
            return
        if outcome[0] == "lose-slots":
            raise SystemExit(f"replay lost on slots during {level['name']}")
        grid = outcome[1]
        slots = list(outcome[2])
    raise SystemExit(f"replay did not clear {level['name']}")


def main() -> None:
    data = load()
    belt_cap = data["beltCapacity"]
    slot_cap = data["slotCapacity"]
    prove_capacities(belt_cap, slot_cap)
    for index, level in enumerate(data["levels"], start=1):
        length, moves = solve(level, belt_cap, slot_cap)
        replay(level, moves, slot_cap)
        print(f"level {index} {level['name']}: solution length {length}")
        print("  " + " -> ".join(moves))


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        sys.exit(0)
