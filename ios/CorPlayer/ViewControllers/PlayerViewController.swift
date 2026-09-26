import UIKit
import AVFoundation

class PlayerViewController: UIViewController {
    private let player = PlayerManager.shared
    private let backgroundImageView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let coverImageView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let lrcLabel = UILabel()
    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let playBtn = UIButton(type: .system)
    private let prevBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let modeBtn = UIButton(type: .system)
    private let downloadBtn = UIButton(type: .system)
    private let closeBtn = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        isModalInPresentation = false
        setupUI()
        setupObservers()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 确保关闭按钮始终在最上层
        view.bringSubviewToFront(closeBtn)
    }

    private func setupUI() {
        let w = view.bounds.width
        let h = view.bounds.height

        // 背景图 + 深色毛玻璃（Liquid Glass）
        backgroundImageView.frame = view.bounds
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)

        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.addSubview(blurView)

        // 关闭按钮 - 44x44 大点击区域，放在安全区域
        closeBtn.frame = CGRect(x: w - 56, y: view.safeAreaInsets.top + 12, width: 44, height: 44)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.8)
        closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        closeBtn.layer.cornerRadius = 22
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        closeBtn.isUserInteractionEnabled = true
        view.addSubview(closeBtn)

        // 封面
        let coverSize = min(w - 80, h * 0.36)
        coverImageView.frame = CGRect(x: (w - coverSize) / 2, y: view.safeAreaInsets.top + 80, width: coverSize, height: coverSize)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.layer.cornerRadius = 16
        coverImageView.clipsToBounds = true
        coverImageView.backgroundColor = .systemGray4
        coverImageView.layer.shadowColor = UIColor.black.cgColor
        coverImageView.layer.shadowOpacity = 0.5
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 12)
        coverImageView.layer.shadowRadius = 30
        view.addSubview(coverImageView)

        // 标题
        titleLabel.frame = CGRect(x: 24, y: coverImageView.frame.maxY + 28, width: w - 48, height: 28)
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 24, y: titleLabel.frame.maxY + 4, width: w - 48, height: 20)
        artistLabel.font = .systemFont(ofSize: 16)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        artistLabel.textAlignment = .center
        view.addSubview(artistLabel)

        // 歌词
        lrcLabel.frame = CGRect(x: 24, y: artistLabel.frame.maxY + 16, width: w - 48, height: 44)
        lrcLabel.font = .systemFont(ofSize: 14)
        lrcLabel.textColor = .systemPink
        lrcLabel.textAlignment = .center
        lrcLabel.numberOfLines = 2
        view.addSubview(lrcLabel)

        // 进度条
        progressSlider.frame = CGRect(x: 28, y: lrcLabel.frame.maxY + 20, width: w - 56, height: 30)
        progressSlider.minimumTrackTintColor = .systemPink
        progressSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        progressSlider.thumbTintColor = .white
        progressSlider.addTarget(self, action: #selector(onSliderChange), for: .valueChanged)
        view.addSubview(progressSlider)

        currentTimeLabel.frame = CGRect(x: 28, y: progressSlider.frame.maxY + 2, width: 60, height: 16)
        currentTimeLabel.font = .systemFont(ofSize: 12)
        currentTimeLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        view.addSubview(currentTimeLabel)

        durationLabel.frame = CGRect(x: w - 88, y: progressSlider.frame.maxY + 2, width: 60, height: 16)
        durationLabel.font = .systemFont(ofSize: 12)
        durationLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        durationLabel.textAlignment = .right
        view.addSubview(durationLabel)

        // 控制按钮
        let btnY = currentTimeLabel.frame.maxY + 24
        let centerX = w / 2

        modeBtn.frame = CGRect(x: centerX - 170, y: btnY + 8, width: 44, height: 44)
        modeBtn.setImage(UIImage(systemName: "repeat"), for: .normal)
        modeBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        modeBtn.addTarget(self, action: #selector(switchMode), for: .touchUpInside)
        view.addSubview(modeBtn)

        prevBtn.frame = CGRect(x: centerX - 110, y: btnY, width: 56, height: 56)
        prevBtn.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        prevBtn.tintColor = .white
        prevBtn.addTarget(self, action: #selector(prevSong), for: .touchUpInside)
        view.addSubview(prevBtn)

        playBtn.frame = CGRect(x: centerX - 36, y: btnY - 4, width: 72, height: 72)
        playBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playBtn.tintColor = .systemPink
        playBtn.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        view.addSubview(playBtn)

        nextBtn.frame = CGRect(x: centerX + 54, y: btnY, width: 56, height: 56)
        nextBtn.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextBtn.tintColor = .white
        nextBtn.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        view.addSubview(nextBtn)

        downloadBtn.frame = CGRect(x: centerX + 126, y: btnY + 8, width: 44, height: 44)
        downloadBtn.setImage(UIImage(systemName: "arrow.down.circle"), for: .normal)
        downloadBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        downloadBtn.addTarget(self, action: #selector(download), for: .touchUpInside)
        view.addSubview(downloadBtn)
    }

    private func setupObservers() {
        player.onStateChange = { [weak self] playing in
            DispatchQueue.main.async {
                self?.playBtn.setImage(UIImage(systemName: playing ? "pause.fill" : "play.fill"), for: .normal)
            }
        }
        player.onProgress = { [weak self] current, duration in
            DispatchQueue.main.async {
                self?.progressSlider.value = duration > 0 ? Float(current / duration) : 0
                self?.currentTimeLabel.text = self?.formatTime(current)
                self?.durationLabel.text = self?.formatTime(duration)
            }
        }
        player.onSongChange = { [weak self] _ in
            DispatchQueue.main.async { self?.updateUI() }
        }
        player.onLrcUpdate = { [weak self] text in
            DispatchQueue.main.async { self?.lrcLabel.text = text }
        }
    }

    private func updateUI() {
        guard let song = player.currentSong else {
            titleLabel.text = "未播放"
            artistLabel.text = ""
            coverImageView.image = nil
            return
        }
        titleLabel.text = song.name
        artistLabel.text = song.singer
        lrcLabel.text = ""
        playBtn.setImage(UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        modeBtn.setImage(UIImage(systemName: player.playMode == .listLoop ? "repeat" : player.playMode == .singleLoop ? "repeat.1" : "shuffle"), for: .normal)
        modeBtn.tintColor = player.playMode == .listLoop ? UIColor.white.withAlphaComponent(0.7) : .systemPink

        let coverUrl = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.png").path : song.coverUrl
        if FileManager.default.fileExists(atPath: coverUrl), let img = UIImage(contentsOfFile: coverUrl) {
            coverImageView.image = img
            backgroundImageView.image = img
        } else if let url = URL(string: coverUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.coverImageView.image = img
                        self?.backgroundImageView.image = img
                    }
                }
            }.resume()
        }
        downloadBtn.isHidden = song.isLocal
        downloadBtn.setImage(UIImage(systemName: song.isLocal ? "checkmark.circle.fill" : "arrow.down.circle"), for: .normal)
        downloadBtn.tintColor = song.isLocal ? .systemGreen : UIColor.white.withAlphaComponent(0.7)
    }

    @objc private func onSliderChange() {
        player.seek(to: TimeInterval(progressSlider.value) * player.duration)
    }
    @objc private func togglePlay() { player.togglePlay() }
    @objc private func prevSong() { player.previous() }
    @objc private func nextSong() { player.next() }
    @objc private func close() { dismiss(animated: true) }

    @objc private func switchMode() {
        let mode = player.switchPlayMode()
        modeBtn.setImage(UIImage(systemName: mode == .listLoop ? "repeat" : mode == .singleLoop ? "repeat.1" : "shuffle"), for: .normal)
        modeBtn.tintColor = mode == .listLoop ? UIColor.white.withAlphaComponent(0.7) : .systemPink
    }

    @objc private func download() {
        guard let song = player.currentSong, !song.isLocal else { return }
        // 通过 NotificationCenter 通知 PlayerBar 显示下载进度
        NotificationCenter.default.post(name: NSNotification.Name("corplayer_download_start"), object: nil, userInfo: ["name": song.name, "progress": 0.0])
        CoresDownloader.shared.downloadCore(song: song, progress: { p in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("corplayer_download_progress"), object: nil, userInfo: ["name": song.name, "progress": p])
            }
        }) { [weak self] result in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("corplayer_download_end"), object: nil)
                if case .success(let localSong) = result {
                    if let idx = PlayerManager.shared.queue.firstIndex(of: song) {
                        PlayerManager.shared.replaceSong(at: idx, with: localSong)
                    }
                    self?.downloadBtn.isHidden = false
                    self?.downloadBtn.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
                    self?.downloadBtn.tintColor = .systemGreen
                }
            }
        }
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
