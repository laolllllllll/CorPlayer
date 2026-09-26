import UIKit
import WebKit

class HomeViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {

    private var webView: WKWebView!
    private let homeURL = "https://music.asinino.cn/app/index.html"

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

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }

        // 拦截 cormusic:// 协议
        if url.scheme == "cormusic" {
            handleCormusicURL(url)
            decisionHandler(.cancel)
            return
        }

        // 拦截 geshou.html 歌手页（在APP内打开）
        if url.absoluteString.contains("geshou.html") {
            decisionHandler(.allow)
            return
        }

        decisionHandler(.allow)
    }

    private func handleCormusicURL(_ url: URL) {
        // cormusic://https://example.com/song.core/
        var raw = url.absoluteString
        raw = raw.replacingOccurrences(of: "cormusic://", with: "")
        // 确保以/结尾
        if !raw.hasSuffix("/") { raw += "/" }

        CoresDownloader.shared.resolveCore(url: raw) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let song):
                    self?.showPlayDialog(song: song)
                case .failure(let error):
                    self?.showAlert(title: "解析失败", message: error.localizedDescription)
                }
            }
        }
    }

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

    private func downloadAndPlay(song: Song) {
        let hud = showLoading("下载中...")
        CoresDownloader.shared.downloadCore(song: song, progress: { p in
            DispatchQueue.main.async { hud.text = "下载中 \(Int(p*100))%" }
        }) { result in
            DispatchQueue.main.async {
                hud.dismiss(animated: false)
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

    // MARK: - 辅助
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func showLoading(_ text: String) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        present(alert, animated: true)
        return alert
    }
}
