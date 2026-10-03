import Foundation

struct ShotEvent: Equatable {
    var column: Int
    var row: Int
    var ammoLeft: Int
}

enum Disposition: Equatable {
    case exited
    case parked
    case won
    case slotsFull
}

/// What one ride did. `grid` and `slots` are the board after the ride.
struct PassResult: Equatable {
    var hue: Hue
    var startedAmmo: Int
    var shots: [ShotEvent]
    var grid: [[Hue?]]
    var slots: [Shooter]
    var disposition: Disposition
}

/// Rules only. SpriteKit stays in GameScene.
///
/// 1. Reject the launch if the conveyor already holds beltCapacity shooters.
/// 2. Take the shooter off the dock or out of a waiting slot.
/// 3. Walk columns from left to right.
/// 4. The adjacent cell in a column is the lowest colored one (closest to the belt).
/// 5. If that cell matches and ammo remains, clear it and spend one ammo.
/// 6. If no colored cells remain, the level is won immediately.
/// 7. If ammo is zero at the end of the ride, the shooter leaves.
/// 8. If ammo remains, it must enter a waiting slot. A full tray fails the level.
struct Board {
    private(set) var grid: [[Hue?]]
    private(set) var dock: [Shooter]
    private(set) var slots: [Shooter]
    private(set) var belt: [Shooter]
    let beltCapacity: Int
    let slotCapacity: Int

    init(level: Level, beltCapacity: Int, slotCapacity: Int) {
        grid = level.grid
        dock = level.shooters
        slots = []
        belt = []
        self.beltCapacity = beltCapacity
        self.slotCapacity = slotCapacity
    }

    var isClear: Bool {
        grid.allSatisfy { row in row.allSatisfy { $0 == nil } }
    }

    /// Puts a dock shooter on the conveyor. False when the belt is full or the index is stale.
    @discardableResult
    mutating func enqueueDock(at index: Int) -> Bool {
        guard belt.count < beltCapacity, dock.indices.contains(index) else { return false }
        belt.append(dock.remove(at: index))
        return true
    }

    /// Puts a waiting shooter back on the conveyor. The slot is freed before the ride.
    @discardableResult
    mutating func enqueueSlot(at index: Int) -> Bool {
        guard belt.count < beltCapacity, slots.indices.contains(index) else { return false }
        belt.append(slots.remove(at: index))
        return true
    }

    mutating func takeFront() -> Shooter? {
        guard !belt.isEmpty else { return nil }
        return belt.removeFirst()
    }

    mutating func applyRide(_ result: PassResult) {
        grid = result.grid
        slots = result.slots
    }

    /// Resolves one ride without touching the belt. `slots` is the tray after the shooter has left it.
    static func ride(grid: [[Hue?]], shooter: Shooter, slots: [Shooter], slotCapacity: Int) -> PassResult {
        var working = grid
        var ammo = shooter.ammo
        var shots: [ShotEvent] = []
        let height = working.count
        let width = working[0].count

        for column in 0..<width {
            if ammo == 0 { break }
            for row in stride(from: height - 1, through: 0, by: -1) {
                guard let cell = working[row][column] else { continue }
                if cell == shooter.hue {
                    working[row][column] = nil
                    ammo -= 1
                    shots.append(ShotEvent(column: column, row: row, ammoLeft: ammo))
                    if working.allSatisfy({ row in row.allSatisfy { $0 == nil } }) {
                        return PassResult(
                            hue: shooter.hue,
                            startedAmmo: shooter.ammo,
                            shots: shots,
                            grid: working,
                            slots: slots,
                            disposition: .won
                        )
                    }
                }
                break
            }
        }

        if ammo == 0 {
            return PassResult(
                hue: shooter.hue,
                startedAmmo: shooter.ammo,
                shots: shots,
                grid: working,
                slots: slots,
                disposition: .exited
            )
        }
        if slots.count >= slotCapacity {
            return PassResult(
                hue: shooter.hue,
                startedAmmo: shooter.ammo,
                shots: shots,
                grid: working,
                slots: slots,
                disposition: .slotsFull
            )
        }
        var parked = slots
        parked.append(Shooter(hue: shooter.hue, ammo: ammo))
        return PassResult(
            hue: shooter.hue,
            startedAmmo: shooter.ammo,
            shots: shots,
            grid: working,
            slots: parked,
            disposition: .parked
        )
    }
}
