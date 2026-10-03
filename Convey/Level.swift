import Foundation

/// A paint chip on the board or on a shooter. Letters match Levels.json.
enum Hue: Equatable, Hashable {
    case red, orange, yellow, green, blue, purple

    init?(letter: Character) {
        switch letter {
        case "R": self = .red
        case "O": self = .orange
        case "Y": self = .yellow
        case "G": self = .green
        case "B": self = .blue
        case "P": self = .purple
        default: return nil
        }
    }

    var letter: Character {
        switch self {
        case .red: return "R"
        case .orange: return "O"
        case .yellow: return "Y"
        case .green: return "G"
        case .blue: return "B"
        case .purple: return "P"
        }
    }
}

/// One launcher. `ammo` is how many cells it can still clear.
struct Shooter: Equatable, Hashable {
    var hue: Hue
    var ammo: Int
}

/// One hand-authored puzzle. `grid` row 0 is the top, away from the conveyor.
struct Level: Equatable {
    var name: String
    var grid: [[Hue?]]
    var shooters: [Shooter]
}

struct Catalog {
    var beltCapacity: Int
    var slotCapacity: Int
    var levels: [Level]
}

enum CatalogError: Error, CustomStringConvertible, LocalizedError {
    case missing
    case invalid(String)

    var description: String {
        switch self {
        case .missing:
            return "Levels.json is missing from the app bundle."
        case .invalid(let reason):
            return reason
        }
    }

    var errorDescription: String? { description }
}

enum LevelBook {
    static func load(from bundle: Bundle = .main) throws -> Catalog {
        guard let url = bundle.url(forResource: "Levels", withExtension: "json") else {
            throw CatalogError.missing
        }
        let data = try Data(contentsOf: url)
        let raw = try JSONSerialization.jsonObject(with: data)
        guard let root = raw as? [String: Any] else {
            throw CatalogError.invalid("Levels.json is not an object.")
        }
        guard let belt = root["beltCapacity"] as? Int, let slots = root["slotCapacity"] as? Int,
              belt > 0, slots > 0 else {
            throw CatalogError.invalid("Capacities must be positive.")
        }
        guard let levels = root["levels"] as? [[String: Any]], !levels.isEmpty else {
            throw CatalogError.invalid("No levels.")
        }
        var parsed: [Level] = []
        for (index, level) in levels.enumerated() {
            parsed.append(try parseLevel(level, number: index + 1))
        }
        return Catalog(beltCapacity: belt, slotCapacity: slots, levels: parsed)
    }

    private static func parseLevel(_ level: [String: Any], number: Int) throws -> Level {
        guard let name = level["name"] as? String, !name.isEmpty else {
            throw CatalogError.invalid("Level \(number) needs a name.")
        }
        guard let rows = level["rows"] as? [String], !rows.isEmpty, rows.count <= 6 else {
            throw CatalogError.invalid("Level \(number) needs 1 to 6 rows.")
        }
        let width = rows[0].count
        if width < 1 || width > 6 {
            throw CatalogError.invalid("Level \(number) needs 1 to 6 columns.")
        }
        var grid: [[Hue?]] = []
        var colored = 0
        for row in rows {
            if row.count != width {
                throw CatalogError.invalid("Level \(number) is not rectangular.")
            }
            var parsed: [Hue?] = []
            for character in row {
                if character == "." {
                    parsed.append(nil)
                } else if let hue = Hue(letter: character) {
                    parsed.append(hue)
                    colored += 1
                } else {
                    throw CatalogError.invalid("Level \(number) has an unknown cell.")
                }
            }
            grid.append(parsed)
        }
        if colored == 0 {
            throw CatalogError.invalid("Level \(number) has no colored cells.")
        }
        guard let shooters = level["shooters"] as? [[String: Any]], !shooters.isEmpty else {
            throw CatalogError.invalid("Level \(number) needs shooters.")
        }
        var dock: [Shooter] = []
        for shooter in shooters {
            guard let letter = shooter["hue"] as? String, letter.count == 1,
                  let hue = Hue(letter: Character(letter)),
                  let ammo = shooter["ammo"] as? Int, ammo > 0 else {
                throw CatalogError.invalid("Level \(number) has a bad shooter.")
            }
            dock.append(Shooter(hue: hue, ammo: ammo))
        }
        return Level(name: name, grid: grid, shooters: dock)
    }
}
