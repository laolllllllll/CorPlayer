import UIKit
import WebKit

class HomeViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private let homeURL = "https://laolllllllll.github.io/CorPlayer/app/index.html"

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
        // 注册 JS 桥接：网页通过 window.webkit.messageHandlers.corPlayer.postMessage(url) 调用
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

    // MARK: - WKScriptMessageHandler（JS桥接，最可靠的方式）
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "corPlayer" else { return }
        if let body = message.body as? String {
            // body 是网页传来的原始 .core URL 字符串
            handleCoreUrl(body)
        } else if let dict = message.body as? [String: Any], let type = dict["type"] as? String {
            if type == "queue", let data = dict["data"] as? String {
                handleQueueData(data)
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
        // 拦截 cormusic:// 协议（备用方式，JS桥接失败时使用）
        if url.scheme == "cormusic" {
            handleCormusicURL(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - 核心处理：直接处理原始URL字符串（不经过NSURL解析）
    private func handleCoreUrl(_ urlString: String) {
        var raw = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        // 如果带了 cormusic:// 前缀，去掉
        if raw.hasPrefix("cormusic://") {
            raw = String(raw.dropFirst("cormusic://".count))
        }
        // 解码百分号（得到含中文的原始URL）
        if let decoded = raw.removingPercentEncoding {
            raw = decoded
        }
        // 重新正确编码（中文→百分号，保留://等）
        let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed).union(.urlUserAllowed).union(.urlPasswordAllowed)
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) {
            raw = encoded
        }
        if !raw.hasSuffix("/") { raw += "/" }

        CoresDownloader.shared.resolveCore(url: raw) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let song):
                    self?.showPlayDialog(song: song)
                case .failure(let error):
                    self?.showAlert(title: "解析失败", message: error.localizedDescription + "\nURL: " + raw)
                }
            }
        }
    }

    // MARK: - 处理队列数据（全部播放）
    private func handleQueueData(_ base64String: String) {
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songs = json["songs"] as? [[String: Any]] else {
            showAlert(title: "队列解析失败", message: "无法解析duilie.json")
            return
        }
        let queueName = json["name"] as? String ?? "播放队列"
        var resolvedCount = 0
        var resolvedSongs: [Song] = []
        let group = DispatchGroup()

        for s in songs {
            guard let coreUrl = s["coreUrl"] as? String else { continue }
            group.enter()
            var raw = coreUrl
            if let decoded = raw.removingPercentEncoding { raw = decoded }
            let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed)
            if let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) { raw = encoded }
            if !raw.hasSuffix("/") { raw += "/" }
            CoresDownloader.shared.resolveCore(url: raw) { result in
                if case .success(let song) = result {
                    resolvedSongs.append(song)
                }
                resolvedCount += 1
                group.leave()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if resolvedSongs.isEmpty {
                self.showAlert(title: "全部播放失败", message: "没有成功解析的歌曲")
                return
            }
            PlayerManager.shared.setQueue(resolvedSongs, playAt: 0)
            self.showAlert(title: "已添加队列", message: "\(queueName)\n共 \(resolvedSongs.count) 首，开始播放")
        }
    }

    // cormusic:// 备用处理
    private func handleCormusicURL(_ url: URL) {
        handleCoreUrl(url.absoluteString)
    }

    // MARK: - 播放弹窗
    private func showPlayDialog(song: Song) {
        let alert = UIAlertController(title: song.name, message: "\(song.singer)\n是否播放？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "播放", style: .default) { _ in
            PlayerManager.shared.addToQueue(song)
            if PlayerManager.shared.currentSong == nil {
                PlayerManager.shared.play()
            } else {
                PlayerManager.shared.setQueue(PlayerManager.shared.queue, playAt: PlayerManager.shared.queue.count - 1)
            }
        })
        alert.addAction(UIAlertAction(title: "下载到本地", style: .default) { _ in
            self.downloadAndPlay(song: song)
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private var loadingAlert: UIAlertController?
    private func downloadAndPlay(song: Song) {
        loadingAlert = UIAlertController(title: nil, message: "下载中 0%", preferredStyle: .alert)
        present(loadingAlert!, animated: true)
        CoresDownloader.shared.downloadCore(song: song, progress: { p in
            DispatchQueue.main.async {
                self.loadingAlert?.message = "下载中 \(Int(p*100))%"
            }
        }) { result in
            DispatchQueue.main.async {
                self.loadingAlert?.dismiss(animated: false)
                self.loadingAlert = nil
                switch result {
                case .success(let localSong):
                    PlayerManager.shared.addToQueue(localSong)
                    if PlayerManager.shared.currentSong == nil {
                        PlayerManager.shared.play()
                    }
                    self.showAlert(title: "下载完成", message: "\(localSong.name) 已保存到本地")
                case .failure(let error):
                    self.showAlert(title: "下载失败", message: error.localizedDescription)
                }
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}
