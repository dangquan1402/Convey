import AVFoundation
import SpriteKit
import UIKit

extension Hue {
    var paint: UIColor {
        switch self {
        case .red: return UIColor(red: 0.86, green: 0.24, blue: 0.27, alpha: 1)
        case .orange: return UIColor(red: 0.95, green: 0.50, blue: 0.16, alpha: 1)
        case .yellow: return UIColor(red: 0.96, green: 0.78, blue: 0.18, alpha: 1)
        case .green: return UIColor(red: 0.18, green: 0.70, blue: 0.42, alpha: 1)
        case .blue: return UIColor(red: 0.20, green: 0.46, blue: 0.92, alpha: 1)
        case .purple: return UIColor(red: 0.56, green: 0.34, blue: 0.82, alpha: 1)
        }
    }

    var ink: UIColor {
        switch self {
        case .yellow, .orange: return UIColor(red: 0.16, green: 0.12, blue: 0.08, alpha: 1)
        default: return .white
        }
    }
}

private struct Metrics {
    var cell: CGFloat = 40
    var gap: CGFloat = 4
    var cols: Int = 1
    var originX: CGFloat = 0
    var topEdge: CGFloat = 0
    var beltY: CGFloat = 0
    var beltLeft: CGFloat = 0
    var beltRight: CGFloat = 0
    var slotY: CGFloat = 0
    var slotRadius: CGFloat = 18
    var dockY: CGFloat = 0
    var dockRadius: CGFloat = 22
    var buttonY: CGFloat = 0
    var statusY: CGFloat = 0

    func center(row: Int, col: Int) -> CGPoint {
        let x = originX + cell / 2 + CGFloat(col) * (cell + gap)
        let y = topEdge - cell / 2 - CGFloat(row) * (cell + gap)
        return CGPoint(x: x, y: y)
    }
}

final class GameScene: SKScene {
    var safeInsets = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0) {
        didSet {
            guard safeInsets != oldValue, !animating else { return }
            layoutAll()
        }
    }

    private var catalog: Catalog?
    private var loadError: String?
    private var index = 0
    private var board = Board(level: Level(name: "", grid: [[nil]], shooters: []), beltCapacity: 5, slotCapacity: 5)
    private var metrics = Metrics()
    private var animating = false
    private var ended: End?
    private var conveyorRejected = false
    private var mover: SKNode?
    private let sound = ClearSound()

    private enum End { case won, lost }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)
        do {
            catalog = try LevelBook.load()
            loadCurrent()
        } catch {
            loadError = error.localizedDescription
            layoutAll()
        }
        sound.prepare()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard !animating else { return }
        layoutAll()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let hit = nodes(at: touch.location(in: self))
        guard let name = hit.compactMap(\.name).first(where: { !$0.isEmpty }) else { return }
        if name == "restart" {
            restart()
            return
        }
        if name == "next" {
            goNext()
            return
        }
        guard ended == nil, catalog != nil else { return }
        if name.hasPrefix("dock-"), let slot = Int(name.dropFirst(5)) {
            tapDock(slot)
        } else if name.hasPrefix("slot-"), let slot = Int(name.dropFirst(5)), !animating {
            tapSlot(slot)
        }
    }

    private func loadCurrent() {
        guard let catalog, catalog.levels.indices.contains(index) else { return }
        let level = catalog.levels[index]
        board = Board(level: level, beltCapacity: catalog.beltCapacity, slotCapacity: catalog.slotCapacity)
        animating = false
        ended = nil
        conveyorRejected = false
        mover?.removeAllActions()
        mover = nil
        layoutAll()
    }

    private func restart() {
        loadCurrent()
    }

    private func goNext() {
        guard ended == .won, let catalog else { return }
        index = (index + 1) % catalog.levels.count
        loadCurrent()
    }

    private func occupied() -> Int {
        board.belt.count + (animating ? 1 : 0)
    }

    private func tapDock(_ index: Int) {
        guard board.dock.indices.contains(index) else { return }
        if occupied() >= board.beltCapacity {
            conveyorRejected = true
            if !animating {
                ended = .lost
                layoutAll()
                showStatus("Conveyor is full")
            }
            return
        }
        guard board.enqueueDock(at: index) else {
            conveyorRejected = true
            if !animating {
                ended = .lost
                layoutAll()
                showStatus("Conveyor is full")
            }
            return
        }
        drawDock()
        drawQueue()
        if !animating { pump() }
    }

    private func tapSlot(_ index: Int) {
        guard board.slots.indices.contains(index) else { return }
        if occupied() >= board.beltCapacity {
            ended = .lost
            layoutAll()
            showStatus("Conveyor is full")
            return
        }
        guard board.enqueueSlot(at: index) else { return }
        drawSlots()
        drawQueue()
        pump()
    }

    private func pump() {
        guard ended == nil, !animating, let shooter = board.takeFront() else { return }
        let result = Board.ride(
            grid: board.grid,
            shooter: shooter,
            slots: board.slots,
            slotCapacity: board.slotCapacity
        )
        animating = true
        drawQueue()
        animate(result)
    }

    private func animate(_ result: PassResult) {
        let radius = min(metrics.cell * 0.38, 18)
        let mover = shooterNode(Shooter(hue: result.hue, ammo: result.startedAmmo), radius: radius)
        mover.position = CGPoint(x: metrics.beltLeft, y: metrics.beltY)
        mover.zPosition = 8
        mover.name = "mover"
        addChild(mover)
        self.mover = mover

        var actions: [SKAction] = []
        var shotIndex = 0
        for column in 0..<metrics.cols {
            let x = metrics.center(row: 0, col: column).x
            actions.append(.moveTo(x: x, duration: 0.11))
            if shotIndex < result.shots.count, result.shots[shotIndex].column == column {
                let shot = result.shots[shotIndex]
                shotIndex += 1
                actions.append(.run { [weak self] in
                    self?.pop(shot)
                    self?.setAmmo(on: mover, shot.ammoLeft)
                    self?.sound.play()
                })
            }
        }
        actions.append(.moveTo(x: metrics.beltRight, duration: 0.10))
        actions.append(.run { [weak self] in
            self?.commit(result)
        })
        mover.run(.sequence(actions), withKey: "ride")
    }

    private func pop(_ shot: ShotEvent) {
        guard let node = childNode(withName: "cell-\(shot.row)-\(shot.column)") else { return }
        node.run(.sequence([.scale(to: 0.01, duration: 0.08), .removeFromParent()]))
    }

    private func setAmmo(on node: SKNode, _ ammo: Int) {
        (node.children.first as? SKLabelNode)?.text = "\(ammo)"
    }

    private func commit(_ result: PassResult) {
        mover?.removeFromParent()
        mover = nil
        animating = false
        board.applyRide(result)

        if result.disposition == .won {
            ended = .won
            conveyorRejected = false
            layoutAll()
            let last = index == (catalog?.levels.count ?? 1) - 1
            showStatus(last ? "All eight cleared" : "Cleared")
            return
        }
        if result.disposition == .slotsFull {
            ended = .lost
            conveyorRejected = false
            layoutAll()
            showStatus("Slots are full")
            return
        }
        if conveyorRejected {
            ended = .lost
            conveyorRejected = false
            layoutAll()
            showStatus("Conveyor is full")
            return
        }
        if board.dock.isEmpty, board.slots.isEmpty, board.belt.isEmpty, !board.isClear {
            ended = .lost
            layoutAll()
            showStatus("Stuck. Restart.")
            return
        }
        layoutAll()
        pump()
    }

    private func layoutAll() {
        removeAllChildren()
        guard size.width > 1, size.height > 1 else { return }
        if let loadError {
            let label = SKLabelNode(fontNamed: "Helvetica")
            label.text = loadError
            label.fontSize = 16
            label.fontColor = .white
            label.position = CGPoint(x: size.width / 2, y: size.height / 2)
            addChild(label)
            return
        }
        guard let catalog, catalog.levels.indices.contains(index) else { return }
        let level = catalog.levels[index]
        let top = max(safeInsets.top, 16)
        let bottom = max(safeInsets.bottom, 12)
        let width = size.width

        let title = label("Convey", font: "Helvetica-Bold", size: 28, color: .white, align: .left)
        title.position = CGPoint(x: 20, y: size.height - top - 22)
        addChild(title)

        let subtitle = label(
            "\(index + 1) of \(catalog.levels.count)   \(level.name)",
            font: "Helvetica",
            size: 16,
            color: UIColor(white: 0.75, alpha: 1),
            align: .left
        )
        subtitle.position = CGPoint(x: 20, y: size.height - top - 50)
        addChild(subtitle)

        let rows = board.grid.count
        let cols = board.grid[0].count
        let gap: CGFloat = 4
        let buttonH: CGFloat = 44
        let buttonY = bottom + 8 + buttonH / 2
        let dockRadius = min(22, (width - 32) / CGFloat(max(board.dock.count, 5)) / 2 - 3)
        let dockY = buttonY + buttonH / 2 + 18 + dockRadius
        let slotRadius: CGFloat = 18
        let slotY = dockY + dockRadius + 30 + slotRadius
        let beltH: CGFloat = 32
        let beltY = slotY + slotRadius + 26 + beltH / 2
        let boardBottom = beltY + beltH / 2 + 12
        let boardTopLimit = size.height - top - 92
        let availableH = max(24, boardTopLimit - boardBottom)
        let availableW = width - 32
        let cellW = (availableW - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (availableH - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let cell = max(10, min(52, cellW, cellH))
        let boardW = cell * CGFloat(cols) + gap * CGFloat(cols - 1)
        let boardH = cell * CGFloat(rows) + gap * CGFloat(rows - 1)
        let originX = (width - boardW) / 2
        let topEdge = boardBottom + (availableH - boardH) / 2 + boardH

        metrics = Metrics(
            cell: cell,
            gap: gap,
            cols: cols,
            originX: originX,
            topEdge: topEdge,
            beltY: beltY,
            beltLeft: 28,
            beltRight: width - 28,
            slotY: slotY,
            slotRadius: slotRadius,
            dockY: dockY,
            dockRadius: max(14, dockRadius),
            buttonY: buttonY,
            statusY: size.height - top - 72
        )

        for row in 0..<rows {
            for col in 0..<cols {
                let center = metrics.center(row: row, col: col)
                let under = SKShapeNode(rectOf: CGSize(width: cell, height: cell))
                under.fillColor = UIColor(white: 0.18, alpha: 1)
                under.strokeColor = .clear
                under.position = center
                under.zPosition = 1
                addChild(under)
                if let hue = board.grid[row][col] {
                    let block = SKShapeNode(rectOf: CGSize(width: max(6, cell - 6), height: max(6, cell - 6)))
                    block.fillColor = hue.paint
                    block.strokeColor = .clear
                    block.position = center
                    block.name = "cell-\(row)-\(col)"
                    block.zPosition = 2
                    addChild(block)
                }
            }
        }

        let belt = SKShapeNode(rectOf: CGSize(width: width - 32, height: beltH))
        belt.fillColor = UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)
        belt.strokeColor = .clear
        belt.position = CGPoint(x: width / 2, y: beltY)
        belt.zPosition = 1
        addChild(belt)

        let waiting = label("Waiting", font: "Helvetica", size: 12, color: UIColor(white: 0.6, alpha: 1), align: .left)
        waiting.position = CGPoint(x: 20, y: slotY + slotRadius + 10)
        addChild(waiting)

        let shooters = label("Shooters", font: "Helvetica", size: 12, color: UIColor(white: 0.6, alpha: 1), align: .left)
        shooters.position = CGPoint(x: 20, y: dockY + metrics.dockRadius + 8)
        addChild(shooters)

        drawSlots()
        drawDock()
        drawQueue()

        let restart = button("Restart", name: "restart", fill: UIColor(white: 0.28, alpha: 1))
        restart.position = CGPoint(x: width / 2 - 78, y: buttonY)
        addChild(restart)
        let next = button("Next", name: "next", fill: UIColor(red: 0.20, green: 0.46, blue: 0.92, alpha: 1))
        next.position = CGPoint(x: width / 2 + 78, y: buttonY)
        next.alpha = ended == .won ? 1 : 0.35
        addChild(next)

        let status = label(idleStatus(), font: "Helvetica-Bold", size: 16, color: .white, align: .left)
        status.name = "status"
        status.position = CGPoint(x: 20, y: metrics.statusY)
        status.zPosition = 20
        addChild(status)
    }

    private func idleStatus() -> String {
        if board.slots.isEmpty && board.belt.isEmpty && !animating {
            return "Tap a shooter"
        }
        return "Slots \(board.slots.count)/\(board.slotCapacity)   Belt \(occupied())/\(board.beltCapacity)"
    }

    private func showStatus(_ text: String) {
        (childNode(withName: "status") as? SKLabelNode)?.text = text
    }

    private func drawSlots() {
        childNode(withName: "slot-layer")?.removeFromParent()
        let layer = SKNode()
        layer.name = "slot-layer"
        layer.zPosition = 5
        let count = board.slotCapacity
        let span = size.width - 48
        for index in 0..<count {
            let x = 24 + span * (CGFloat(index) + 0.5) / CGFloat(count)
            if index < board.slots.count {
                let node = shooterNode(board.slots[index], radius: metrics.slotRadius)
                node.position = CGPoint(x: x, y: metrics.slotY)
                tag(node, "slot-\(index)")
                layer.addChild(node)
            } else {
                let empty = SKShapeNode(circleOfRadius: metrics.slotRadius)
                empty.strokeColor = UIColor(white: 0.35, alpha: 1)
                empty.fillColor = .clear
                empty.lineWidth = 2
                empty.position = CGPoint(x: x, y: metrics.slotY)
                layer.addChild(empty)
            }
        }
        addChild(layer)
    }

    private func drawDock() {
        childNode(withName: "dock-layer")?.removeFromParent()
        let layer = SKNode()
        layer.name = "dock-layer"
        layer.zPosition = 5
        let radius = metrics.dockRadius
        let spacing = radius * 2 + 8
        let total = CGFloat(max(board.dock.count, 1)) * spacing - 8
        var x = (size.width - total) / 2 + radius
        if board.dock.isEmpty { x = size.width / 2 }
        for (index, shooter) in board.dock.enumerated() {
            let node = shooterNode(shooter, radius: radius)
            node.position = CGPoint(x: x, y: metrics.dockY)
            tag(node, "dock-\(index)")
            layer.addChild(node)
            x += spacing
        }
        addChild(layer)
    }

    private func drawQueue() {
        childNode(withName: "queue-layer")?.removeFromParent()
        let layer = SKNode()
        layer.name = "queue-layer"
        layer.zPosition = 4
        for (index, shooter) in board.belt.enumerated() {
            let node = shooterNode(shooter, radius: 11)
            node.position = CGPoint(x: metrics.beltLeft + 14 + CGFloat(index) * 26, y: metrics.beltY)
            layer.addChild(node)
        }
        addChild(layer)
    }

    private func shooterNode(_ shooter: Shooter, radius: CGFloat) -> SKShapeNode {
        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = shooter.hue.paint
        circle.strokeColor = .clear
        let ammo = SKLabelNode(fontNamed: "Helvetica-Bold")
        ammo.text = "\(shooter.ammo)"
        ammo.fontSize = max(11, radius * 0.85)
        ammo.fontColor = shooter.hue.ink
        ammo.verticalAlignmentMode = .center
        ammo.horizontalAlignmentMode = .center
        ammo.zPosition = 1
        circle.addChild(ammo)
        return circle
    }

    private func button(_ title: String, name: String, fill: UIColor) -> SKNode {
        let shape = SKShapeNode(rectOf: CGSize(width: 132, height: 44))
        shape.fillColor = fill
        shape.strokeColor = .clear
        let text = SKLabelNode(fontNamed: "Helvetica-Bold")
        text.text = title
        text.fontSize = 18
        text.fontColor = .white
        text.verticalAlignmentMode = .center
        text.horizontalAlignmentMode = .center
        shape.addChild(text)
        tag(shape, name)
        return shape
    }

    private func label(_ text: String, font: String, size: CGFloat, color: UIColor, align: SKLabelHorizontalAlignmentMode) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: font)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.horizontalAlignmentMode = align
        node.verticalAlignmentMode = .center
        return node
    }

    private func tag(_ node: SKNode, _ name: String) {
        node.name = name
        for child in node.children {
            child.name = name
        }
    }
}

private final class ClearSound {
    private var player: AVAudioPlayer?

    func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let url = Bundle.main.url(forResource: "clear.wav", withExtension: "b64"),
              let text = try? String(contentsOf: url, encoding: .utf8),
              let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
    }

    func play() {
        player?.currentTime = 0
        player?.play()
    }
}
