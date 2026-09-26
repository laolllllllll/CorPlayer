import UIKit

class PlayerBar: UIView {
    private let player = PlayerManager.shared
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let downloadProgressView = UIProgressView(progressViewStyle: .default)
    private let downloadLabel = UILabel()
    private var isDownloading = false

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        // Liquid Glass 毛玻璃背景
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.75)
        addSubview(blurView)

        // 顶部高光边线（Liquid Glass 特征）
        let topLine = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: 0.5))
        topLine.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        topLine.autoresizingMask = [.flexibleWidth]
        addSubview(topLine)

        // 封面
        coverView.frame = CGRect(x: 12, y: 8, width: 48, height: 48)
        coverView.layer.cornerRadius = 10
        coverView.clipsToBounds = true
        coverView.backgroundColor = .systemGray4
        coverView.contentMode = .scaleAspectFill
        coverView.layer.shadowColor = UIColor.black.cgColor
        coverView.layer.shadowOpacity = 0.3
        coverView.layer.shadowOffset = CGSize(width: 0, height: 2)
        coverView.layer.shadowRadius = 6
        addSubview(coverView)

        // 标题
        titleLabel.frame = CGRect(x: 72, y: 12, width: bounds.width - 180, height: 22)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 72, y: 34, width: bounds.width - 180, height: 18)
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        addSubview(artistLabel)

        // 按钮
        let w = bounds.width
        nextBtn.frame = CGRect(x: w - 52, y: 16, width: 36, height: 36)
        nextBtn.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextBtn.tintColor = .white
        nextBtn.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        addSubview(nextBtn)

        playBtn.frame = CGRect(x: w - 96, y: 16, width: 36, height: 36)
        playBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playBtn.tintColor = .systemPink
        playBtn.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        addSubview(playBtn)

        // 播放进度条（底部细线）
        progressView.frame = CGRect(x: 0, y: 62, width: bounds.width, height: 2)
        progressView.tintColor = .systemPink
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressView.progress = 0
        addSubview(progressView)

        // 下载进度条（默认隐藏）
        downloadProgressView.frame = CGRect(x: 12, y: 56, width: bounds.width - 24, height: 4)
        downloadProgressView.tintColor = .systemBlue
        downloadProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        downloadProgressView.layer.cornerRadius = 2
        downloadProgressView.clipsToBounds = true
        downloadProgressView.isHidden = true
        addSubview(downloadProgressView)

        downloadLabel.frame = CGRect(x: 72, y: 34, width: bounds.width - 180, height: 18)
        downloadLabel.font = .systemFont(ofSize: 11)
        downloadLabel.textColor = .systemBlue
        downloadLabel.isHidden = true
        addSubview(downloadLabel)

        // 点击打开全屏
        let tap = UITapGestureRecognizer(target: self, action: #selector(barTapped))
        addGestureRecognizer(tap)

        isHidden = true
        alpha = 0
    }

    // 下载进度显示
    func showDownloadProgress(_ progress: Double, songName: String) {
        isDownloading = true
        downloadProgressView.isHidden = false
        downloadLabel.isHidden = false
        downloadProgressView.progress = Float(progress)
        downloadLabel.text = "正在下载 \(songName) \(Int(progress * 100))%"
        artistLabel.isHidden = true
    }

    func hideDownloadProgress() {
        isDownloading = false
        downloadProgressView.isHidden = true
        downloadLabel.isHidden = true
        artistLabel.isHidden = false
    }

    private func setupObservers() {
        player.onSongChange = { [weak self] song in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let hasSong = song != nil
                self.isHidden = !hasSong
                UIView.animate(withDuration: 0.3) { self.alpha = hasSong ? 1 : 0 }
                self.updateUI()
            }
        }
        player.onStateChange = { [weak self] playing in
            DispatchQueue.main.async {
                self?.playBtn.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
            }
        }
        player.onProgress = { [weak self] current, duration in
            DispatchQueue.main.async {
                self?.progressView.progress = duration > 0 ? Float(current / duration) : 0
            }
        }
        // 监听下载进度通知
        NotificationCenter.default.addObserver(forName: NSNotification.Name("corplayer_download_start"), object: nil, queue: .main) { [weak self] note in
            let name = note.userInfo?["name"] as? String ?? ""
            self?.showDownloadProgress(0, songName: name)
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("corplayer_download_progress"), object: nil, queue: .main) { [weak self] note in
            let name = note.userInfo?["name"] as? String ?? ""
            let progress = note.userInfo?["progress"] as? Double ?? 0
            self?.showDownloadProgress(progress, songName: name)
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("corplayer_download_end"), object: nil, queue: .main) { [weak self] _ in
            self?.hideDownloadProgress()
        }
    }

    private func updateUI() {
        guard let song = player.currentSong else { return }
        titleLabel.text = song.name
        artistLabel.text = song.singer
        playBtn.setImage(UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        let coverPath = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.png").path : song.coverUrl
        if FileManager.default.fileExists(atPath: coverPath), let img = UIImage(contentsOfFile: coverPath) {
            coverView.image = img
        } else if let url = URL(string: coverPath) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { self?.coverView.image = img }
                }
            }.resume()
        }
    }

    @objc private func toggle() { player.togglePlay() }
    @objc private func nextSong() { player.next() }
    @objc private func barTapped() { onTap?() }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        titleLabel.frame = CGRect(x: 72, y: 12, width: w - 180, height: 22)
        artistLabel.frame = CGRect(x: 72, y: 34, width: w - 180, height: 18)
        downloadLabel.frame = CGRect(x: 72, y: 34, width: w - 180, height: 18)
        nextBtn.frame = CGRect(x: w - 52, y: 16, width: 36, height: 36)
        playBtn.frame = CGRect(x: w - 96, y: 16, width: 36, height: 36)
        progressView.frame = CGRect(x: 0, y: 62, width: w, height: 2)
        downloadProgressView.frame = CGRect(x: 12, y: 56, width: w - 24, height: 4)
    }
}
