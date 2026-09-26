import UIKit

class PlayerBar: UIView {
    private let player = PlayerManager.shared
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        addSubview(blurView)

        let topLine = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: 0.5))
        topLine.backgroundColor = .separator
        topLine.autoresizingMask = [.flexibleWidth]
        addSubview(topLine)

        coverView.frame = CGRect(x: 12, y: 8, width: 48, height: 48)
        coverView.layer.cornerRadius = 8
        coverView.clipsToBounds = true
        coverView.backgroundColor = .systemGray4
        coverView.contentMode = .scaleAspectFill
        addSubview(coverView)

        titleLabel.frame = CGRect(x: 72, y: 12, width: bounds.width - 180, height: 22)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 72, y: 34, width: bounds.width - 180, height: 18)
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .secondaryLabel
        addSubview(artistLabel)

        let w = bounds.width
        nextBtn.frame = CGRect(x: w - 52, y: 16, width: 36, height: 36)
        nextBtn.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextBtn.tintColor = .label
        nextBtn.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        addSubview(nextBtn)

        playBtn.frame = CGRect(x: w - 96, y: 16, width: 36, height: 36)
        playBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playBtn.tintColor = .systemPink
        playBtn.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        addSubview(playBtn)

        progressView.frame = CGRect(x: 12, y: 60, width: bounds.width - 24, height: 2)
        progressView.tintColor = .systemPink
        progressView.trackTintColor = .clear
        progressView.progress = 0
        addSubview(progressView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(barTapped))
        addGestureRecognizer(tap)
        isHidden = true
        alpha = 0
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

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        titleLabel.frame = CGRect(x: 72, y: 12, width: w - 180, height: 22)
        artistLabel.frame = CGRect(x: 72, y: 34, width: w - 180, height: 18)
        nextBtn.frame = CGRect(x: w - 52, y: 16, width: 36, height: 36)
        playBtn.frame = CGRect(x: w - 96, y: 16, width: 36, height: 36)
        progressView.frame = CGRect(x: 12, y: 60, width: w - 24, height: 2)
    }
}
