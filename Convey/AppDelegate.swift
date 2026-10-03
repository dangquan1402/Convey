import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
