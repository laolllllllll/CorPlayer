import UIKit

class PlayerViewController: UIViewController {

    private let player = PlayerManager.shared
    private var coverImageView = UIImageView()
    private var titleLabel = UILabel()
    private var artistLabel = UILabel()
    private var lrcLabel = UILabel()
    private var progressSlider = UISlider()
    private var currentTimeLabel = UILabel()
    private var durationLabel = UILabel()
    private var playBtn = UIButton()
    private var prevBtn = UIButton()
    private var nextBtn = UIButton()
    private var modeBtn = UIButton()
    private var downloadBtn = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupObservers()
        updateUI()
    }

    private func setupUI() {
        // 毛玻璃背景
        let blur = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = view.bounds
        view.addSubview(blurView)

        // 封面
        coverImageView.frame = CGRect(x: 60, y: 80, width: view.bounds.width - 120, height: view.bounds.width - 120)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.layer.cornerRadius = 12
        coverImageView.clipsToBounds = true
        coverImageView.backgroundColor = .darkGray
        view.addSubview(coverImageView)

        // 标题
        titleLabel.frame = CGRect(x: 20, y: coverImageView.frame.maxY + 24, width: view.bounds.width - 40, height: 28)
        titleLabel.font = .boldSystemFont(ofSize: 20)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 20, y: titleLabel.frame.maxY + 4, width: view.bounds.width - 40, height: 20)
        artistLabel.font = .systemFont(ofSize: 14)
        artistLabel.textColor = .lightGray
        artistLabel.textAlignment = .center
        view.addSubview(artistLabel)

        // 歌词
        lrcLabel.frame = CGRect(x: 20, y: artistLabel.frame.maxY + 16, width: view.bounds.width - 40, height: 40)
        lrcLabel.font = .systemFont(ofSize: 14)
        lrcLabel.textColor = .systemRed
        lrcLabel.textAlignment = .center
        lrcLabel.numberOfLines = 2
        view.addSubview(lrcLabel)

        // 进度条
        progressSlider.frame = CGRect(x: 30, y: lrcLabel.frame.maxY + 20, width: view.bounds.width - 60, height: 30)
        progressSlider.minimumTrackTintColor = .systemRed
        progressSlider.maximumTrackTintColor = .darkGray
        progressSlider.addTarget(self, action: #selector(onSliderChange), for: .valueChanged)
        view.addSubview(progressSlider)

        currentTimeLabel.frame = CGRect(x: 30, y: progressSlider.frame.maxY + 4, width: 60, height: 16)
        currentTimeLabel.font = .systemFont(ofSize: 11)
        currentTimeLabel.textColor = .gray
        view.addSubview(currentTimeLabel)

        durationLabel.frame = CGRect(x: view.bounds.width - 90, y: progressSlider.frame.maxY + 4, width: 60, height: 16)
        durationLabel.font = .systemFont(ofSize: 11)
        durationLabel.textColor = .gray
        durationLabel.textAlignment = .right
        view.addSubview(durationLabel)

        // 控制按钮
        let btnY = currentTimeLabel.frame.maxY + 30
        let btnSize: CGFloat = 50
        let centerX = view.bounds.width / 2

        modeBtn.frame = CGRect(x: centerX - 160, y: btnY + 10, width: 40, height: 40)
        modeBtn.setTitle("🔁", for: .normal)
        modeBtn.titleLabel?.font = .systemFont(ofSize: 22)
        modeBtn.addTarget(self, action: #selector(switchMode), for: .touchUpInside)
        view.addSubview(modeBtn)

        prevBtn.frame = CGRect(x: centerX - 100, y: btnY, width: btnSize, height: btnSize)
        prevBtn.setTitle("⏮", for: .normal)
        prevBtn.titleLabel?.font = .systemFont(ofSize: 28)
        prevBtn.addTarget(self, action: #selector(prev), for: .touchUpInside)
        view.addSubview(prevBtn)

        playBtn.frame = CGRect(x: centerX - 30, y: btnY - 5, width: 60, height: 60)
        playBtn.setTitle("▶️", for: .normal)
        playBtn.titleLabel?.font = .systemFont(ofSize: 32)
        playBtn.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)
        view.addSubview(playBtn)

        nextBtn.frame = CGRect(x: centerX + 50, y: btnY, width: btnSize, height: btnSize)
        nextBtn.setTitle("⏭", for: .normal)
        nextBtn.titleLabel?.font = .systemFont(ofSize: 28)
        nextBtn.addTarget(self, action: #selector(next), for: .touchUpInside)
        view.addSubview(nextBtn)

        downloadBtn.frame = CGRect(x: centerX + 120, y: btnY + 10, width: 40, height: 40)
        downloadBtn.setTitle("⬇️", for: .normal)
        downloadBtn.titleLabel?.font = .systemFont(ofSize: 22)
        downloadBtn.addTarget(self, action: #selector(download), for: .touchUpInside)
        view.addSubview(downloadBtn)
    }

    private func setupObservers() {
        player.onStateChange = { [weak self] playing in
            DispatchQueue.main.async { self?.playBtn.setTitle(playing ? "⏸" : "▶️", for: .normal) }
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
        playBtn.setTitle(player.isPlaying ? "⏸" : "▶️", for: .normal)
        modeBtn.setTitle(player.playMode == .listLoop ? "🔁" : player.playMode == .singleLoop ? "🔂" : "🔀", for: .normal)

        // 加载封面
        let coverUrl = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent.appendingPathComponent("info.png").path : song.coverUrl
        if let url = URL(string: coverUrl) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { self.coverImageView.image = img }
                }
            }.resume()
        } else if FileManager.default.fileExists(atPath: coverUrl), let img = UIImage(contentsOfFile: coverUrl) {
            coverImageView.image = img
        }
        downloadBtn.isHidden = song.isLocal
    }

    @objc private func onSliderChange() {
        player.seek(to: TimeInterval(progressSlider.value) * player.duration)
    }

    @objc private func togglePlay() { player.togglePlay() }
    @objc private func prev() { player.previous() }
    @objc private func next() { player.next() }

    @objc private func switchMode() {
        let mode = player.switchPlayMode()
        modeBtn.setTitle(mode == .listLoop ? "🔁" : mode == .singleLoop ? "🔂" : "🔀", for: .normal)
    }

    @objc private func download() {
        guard let song = player.currentSong, !song.isLocal else { return }
        let alert = UIAlertController(title: "下载", message: "下载到本地播放？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "下载", style: .default) { _ in
            CoresDownloader.shared.downloadCore(song: song, progress: { _ in }) { result in
                DispatchQueue.main.async {
                    if case .success(let localSong) = result {
                        // 替换队列中的歌曲为本地版本
                        if let idx = PlayerManager.shared.queue.firstIndex(of: song) {
                            PlayerManager.shared.queue[idx] = localSong
                        }
                        self.downloadBtn.isHidden = true
                        self.showAlert(title: "下载完成", message: "\(localSong.name) 已保存")
                    }
                }
            }
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
