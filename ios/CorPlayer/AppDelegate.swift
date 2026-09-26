import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = MainTabBarController()
        window?.overrideUserInterfaceStyle = .dark
        window?.makeKeyAndVisible()
        return true
    }

    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        handleURL(url)
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        handleURL(url)
        return true
    }

    private func handleURL(_ url: URL) {
        if url.scheme == "cormusic" {
            var raw = url.absoluteString
            if raw.hasPrefix("cormusic://") {
                raw = String(raw.dropFirst("cormusic://".count))
            }
            if let decoded = raw.removingPercentEncoding {
                raw = decoded
            }
            let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed).union(.urlUserAllowed).union(.urlPasswordAllowed)
            if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) {
                raw = encoded
            }
            if !raw.hasSuffix("/") { raw += "/" }
            CoresDownloader.shared.resolveCore(url: raw) { result in
                DispatchQueue.main.async {
                    if case .success(let song) = result {
                        PlayerManager.shared.addToQueue(song)
                        if PlayerManager.shared.currentSong == nil {
                            PlayerManager.shared.play()
                        }
                    }
                }
            }
        }
    }
}
