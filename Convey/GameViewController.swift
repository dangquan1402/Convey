import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    private var skView: SKView!
    private var gameScene: GameScene!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)
        let skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        view.addSubview(skView)
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .resizeFill
        self.skView = skView
        gameScene = scene
        skView.presentScene(scene)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gameScene.safeInsets = view.safeAreaInsets
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
