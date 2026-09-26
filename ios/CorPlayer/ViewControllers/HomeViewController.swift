import UIKit
import WebKit

class HomeViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private var homeURL: String {
        UserDefaults.standard.string(forKey: "corplayer_home_url") ?? "https://laolllllllll.github.io/CorPlayer/app/index.html"
    }
    private var loadingAlert: UIAlertController?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "首页"
        view.backgroundColor = .black
        setupWebView()
        loadHome()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(self, name: "corPlayer")
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.isOpaque = false
        view.addSubview(webView)
    }

    private func loadHome() {
        if let url = URL(string: homeURL) {
            webView.load(URLRequest(url: url))
        }
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "corPlayer" else { return }
        if let body = message.body as? String {
            handleCoreUrl(body)
        } else if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
            if type == "queue", let data = dict["data"] as? String {
                let save = dict["saveFile"] as? Bool ?? false
                handleQueueData(data, saveFile: save)
            } else if type == "play", let url = dict["url"] as? String {
                handleCoreUrl(url)
            }
        }
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        if url.scheme == "cormusic" {
            handleCoreUrl(url.absoluteString)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - 核心处理
    private func handleCoreUrl(_ urlString: String) {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("cormusic://") {
            raw = String(raw.dropFirst("cormusic://".count))
        }
        if let decoded = raw.removingPercentEncoding { raw = decoded }
        let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed).union(.urlUserAllowed).union(.urlPasswordAllowed)
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) { raw = encoded }
        if !raw.hasSuffix("/") { raw += "/" }

        CoresDownloader.shared.resolveCore(url: raw) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let song):
                    // 直接添加到队列并播放，不弹窗
                    PlayerManager.shared.addToQueue(song)
                    if PlayerManager.shared.currentSong == nil {
                        PlayerManager.shared.play()
                    } else {
                        PlayerManager.shared.setQueue(PlayerManager.shared.queue, playAt: PlayerManager.shared.queue.count - 1)
                    }
                case .failure(let error):
                    self?.showAlert(title: "解析失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func handleQueueData(_ base64String: String, saveFile: Bool = false) {
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songs = json["songs"] as? [[String: Any]] else {
            showAlert(title: "队列解析失败", message: "无法解析duilie.json")
            return
        }
        // 保存 duilie.json 到 Documents
        if saveFile {
            let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let filePath = docsPath.appendingPathComponent("duilie.json")
            try? data.write(to: filePath)
        }
        var resolvedSongs: [Song] = []
        let group = DispatchGroup()

        for s in songs {
            guard let coreUrl = s["coreUrl"] as? String else { continue }
            var raw = coreUrl
            if let decoded = raw.removingPercentEncoding { raw = decoded }
            let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed)
            if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) { raw = encoded }
            if !raw.hasSuffix("/") { raw += "/" }
            group.enter()
            CoresDownloader.shared.resolveCore(url: raw) { result in
                if case .success(let song) = result { resolvedSongs.append(song) }
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            if resolvedSongs.isEmpty {
                self?.showAlert(title: "全部播放失败", message: "没有成功解析的歌曲")
                return
            }
            PlayerManager.shared.setQueue(resolvedSongs, playAt: 0)
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
