import UIKit

class MainTabBarController: UITabBarController {

    private var playerBar: PlayerBar!
    private var playerVC: PlayerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupPlayerBar()
    }

    private func setupTabs() {
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "首页", image: UIImage(systemName: "house"), tag: 0)

        let queue = UINavigationController(rootViewController: QueueViewController())
        queue.tabBarItem = UITabBarItem(title: "队列", image: UIImage(systemName: "list.bullet"), tag: 1)

        let me = UINavigationController(rootViewController: MeViewController())
        me.tabBarItem = UITabBarItem(title: "我的", image: UIImage(systemName: "person"), tag: 2)

        viewControllers = [home, queue, me]
        tabBar.barTintColor = .black
        tabBar.tintColor = .systemRed
        tabBar.unselectedItemTintColor = .gray
    }

    private func setupPlayerBar() {
        let barHeight: CGFloat = 56
        let tabBarHeight = tabBar.frame.height
        playerBar = PlayerBar(frame: CGRect(x: 0, y: view.bounds.height - tabBarHeight - barHeight, width: view.bounds.width, height: barHeight))
        playerBar.onTap = { [weak self] in
            self?.showFullPlayer()
        }
        view.addSubview(playerBar)
    }

    private func showFullPlayer() {
        if playerVC == nil {
            playerVC = PlayerViewController()
            playerVC?.modalPresentationStyle = .pageSheet
        }
        present(playerVC!, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let barHeight: CGFloat = 56
        let tabBarHeight = tabBar.frame.height
        playerBar.frame = CGRect(x: 0, y: view.bounds.height - tabBarHeight - barHeight, width: view.bounds.width, height: barHeight)
    }
}
