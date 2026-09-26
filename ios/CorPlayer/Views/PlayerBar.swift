import UIKit

class PlayerBar: UIView {
    private let player = PlayerManager.shared
    private var coverView = UIImageView()
    private var titleLabel = UILabel()
    private var artistLabel = UILabel()
    private var playBtn = UIButton()
    private var nextBtn = UIButton()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupObservers()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.95)

        coverView.frame = CGRect(x: 12, y: 6, width: 44, height: 44)
        coverView.layer.cornerRadius = 6
        coverView.clipsToBounds = true
        coverView.backgroundColor = .darkGray
        coverView.contentMode = .scaleAspectFill
        addSubview(coverView)

        titleLabel.frame = CGRect(x: 68, y: 8, width: 160, height: 20)
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 68, y: 30, width: 160, height: 16)
        artistLabel.font = .systemFont(ofSize: 11)
        artistLabel.textColor = .gray
        addSubview(artistLabel)

        let width = UIScreen.main.bounds.width
        nextBtn.frame = CGRect(x: width - 56, y: 13, width: 36, height: 36)
        nextBtn.setTitle("⏭", for: .normal)
        nextBtn.titleLabel?.font = .systemFont(ofSize: 20)
        nextBtn.addTarget(self, action: #selector(nextSong), for: .touchUpInside)
        addSubview(nextBtn)

        playBtn.frame = CGRect(x: width - 100, y: 13, width: 36, height: 36)
        playBtn.setTitle("▶️", for: .normal)
        playBtn.titleLabel?.font = .systemFont(ofSize: 22)
        playBtn.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        addSubview(playBtn)

        // 点击打开全屏播放器
        let tap = UITapGestureRecognizer(target: self, action: #selector(barTapped))
        addGestureRecognizer(tap)

        isHidden = true
    }

    private func setupObservers() {
        player.onSongChange = { [weak self] song in
            DispatchQueue.main.async {
                self?.isHidden = song == nil
                self?.updateUI()
            }
        }
        player.onStateChange = { [weak self] playing in
            DispatchQueue.main.async { self?.playBtn.setTitle(playing ? "⏸" : "▶️", for: .normal) }
        }
    }

    private func updateUI() {
        guard let song = player.currentSong else { return }
        titleLabel.text = song.name
        artistLabel.text = song.singer
        playBtn.setTitle(player.isPlaying ? "⏸" : "▶️", for: .normal)

        let coverPath = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.png").path : song.coverUrl
        if FileManager.default.fileExists(atPath: coverPath), let img = UIImage(contentsOfFile: coverPath) {
            coverView.image = img
        } else if let url = URL(string: coverPath) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { self.coverView.image = img }
                }
            }.resume()
        }
    }

    @objc private func toggle() { player.togglePlay() }
    @objc private func nextSong() { player.next() }
    @objc private func barTapped() { onTap?() }
}
