import UIKit

class MainTabBarController: UITabBarController {

    private var playerBar: PlayerBar!
    private var playerVC: PlayerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupPlayerBar()
        setupTabBarAppearance()
    }

    private func setupTabs() {
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "首页", image: UIImage(systemName: "house.fill"), tag: 0)

        let queue = UINavigationController(rootViewController: QueueViewController())
        queue.tabBarItem = UITabBarItem(title: "队列", image: UIImage(systemName: "list.bullet"), tag: 1)

        let me = UINavigationController(rootViewController: MeViewController())
        me.tabBarItem = UITabBarItem(title: "我的", image: UIImage(systemName: "person.fill"), tag: 2)

        viewControllers = [home, queue, me]
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        appearance.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.7)
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = .systemPink
        tabBar.unselectedItemTintColor = UIColor.white.withAlphaComponent(0.5)
    }

    private func setupPlayerBar() {
        let barHeight: CGFloat = 64
        playerBar = PlayerBar(frame: CGRect(x: 0, y: view.bounds.height - tabBar.frame.height - barHeight, width: view.bounds.width, height: barHeight))
        playerBar.onTap = { [weak self] in self?.showFullPlayer() }
        view.addSubview(playerBar)
    }

    private func showFullPlayer() {
        if playerVC == nil {
            playerVC = PlayerViewController()
            playerVC?.modalPresentationStyle = .fullScreen
            playerVC?.modalTransitionStyle = .coverVertical
        }
        present(playerVC!, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let barHeight: CGFloat = 64
        let tabBarHeight = tabBar.frame.height
        playerBar.frame = CGRect(x: 0, y: view.bounds.height - tabBarHeight - barHeight, width: view.bounds.width, height: barHeight)
    }
}
