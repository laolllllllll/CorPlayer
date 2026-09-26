import UIKit
import AVFoundation

class PlayerViewController: UIViewController {
    private let player = PlayerManager.shared
    private let backgroundImageView = UIImageView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let coverImageView = UIImageView()
    private let lrcTableView = UITableView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let playBtn = UIButton(type: .system)
    private let prevBtn = UIButton(type: .system)
    private let nextBtn = UIButton(type: .system)
    private let modeBtn = UIButton(type: .system)
    private let downloadBtn = UIButton(type: .system)
    private let closeBtn = UIButton(type: .system)
    private let downIndicator = UIView()

    private var lrcLines: [(time: TimeInterval, text: String)] = []
    private var currentLrcIndex: Int = -1
    private var showingLrc = false
    private var panGesture: UIPanGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        isModalInPresentation = false
        modalPresentationStyle = .fullScreen
        setupUI()
        setupPanGesture()
        setupObservers()
        loadLrc()
        updateUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.bringSubviewToFront(closeBtn)
        view.bringSubviewToFront(downIndicator)
    }

    private func setupUI() {
        let w = view.bounds.width
        let h = view.bounds.height

        backgroundImageView.frame = view.bounds
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)

        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        view.addSubview(blurView)

        downIndicator.frame = CGRect(x: (w - 40) / 2, y: view.safeAreaInsets.top + 8, width: 40, height: 5)
        downIndicator.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        downIndicator.layer.cornerRadius = 2.5
        view.addSubview(downIndicator)

        closeBtn.frame = CGRect(x: w - 56, y: view.safeAreaInsets.top + 12, width: 44, height: 44)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = UIColor.white.withAlphaComponent(0.8)
        closeBtn.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        closeBtn.layer.cornerRadius = 22
        closeBtn.addTarget(self, action: #selector(close), for: .touchUpInside)
        view.addSubview(closeBtn)

        let coverSize = min(w - 80, h * 0.36)
        coverImageView.frame = CGRect(x: (w - coverSize) / 2, y: view.safeAreaInsets.top + 70, width: coverSize, height: coverSize)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.layer.cornerRadius = 16
        coverImageView.clipsToBounds = true
        coverImageView.backgroundColor = .systemGray4
        coverImageView.isUserInteractionEnabled = true
        coverImageView.layer.shadowColor = UIColor.black.cgColor
        coverImageView.layer.shadowOpacity = 0.5
        coverImageView.layer.shadowOffset = CGSize(width: 0, height: 12)
        coverImageView.layer.shadowRadius = 30
        let coverTap = UITapGestureRecognizer(target: self, action: #selector(toggleLrc))
        coverImageView.addGestureRecognizer(coverTap)
        view.addSubview(coverImageView)

        lrcTableView.frame = CGRect(x: 20, y: view.safeAreaInsets.top + 70, width: w - 40, height: coverSize)
        lrcTableView.backgroundColor = .clear
        lrcTableView.separatorStyle = .none
        lrcTableView.showsVerticalScrollIndicator = false
        lrcTableView.dataSource = self
        lrcTableView.delegate = self
        lrcTableView.register(LrcCell.self, forCellReuseIdentifier: "LrcCell")
        lrcTableView.isHidden = true
        lrcTableView.alpha = 0
        lrcTableView.contentInset = UIEdgeInsets(top: coverSize / 2 - 30, left: 0, bottom: coverSize / 2 - 30, right: 0)
        let lrcTap = UITapGestureRecognizer(target: self, action: #selector(toggleLrc))
        lrcTableView.addGestureRecognizer(lrcTap)
        view.addSubview(lrcTableView)

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

        progressSlider.frame = CGRect(x: 28, y: artistLabel.frame.maxY + 24, width: w - 56, height: 30)
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

    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                let progress = min(translation.y / 400, 1.0)
                view.transform = CGAffineTransform(translationX: 0, y: translation.y)
                view.alpha = 1 - progress * 0.5
                blurView.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.55 - progress * 0.3)
            }
        case .ended, .cancelled:
            if translation.y > 150 || velocity.y > 800 {
                dismiss(animated: true) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                    self.blurView.contentView.backgroundColor = UIColor.black.withAlphaComponent(0.55)
                }
            }
        default: break
        }
    }

    @objc private func toggleLrc() {
        showingLrc.toggle()
        UIView.animate(withDuration: 0.3) {
            self.coverImageView.alpha = self.showingLrc ? 0 : 1
            self.lrcTableView.alpha = self.showingLrc ? 1 : 0
        }
        lrcTableView.isHidden = !showingLrc
        coverImageView.isHidden = showingLrc
        if showingLrc { scrollToCurrentLrc(animated: false) }
    }

    private func loadLrc() {
        guard let song = player.currentSong else { return }
        let lrcPath = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.lrc").path : song.lrcUrl
        if FileManager.default.fileExists(atPath: lrcPath), let lrcStr = try? String(contentsOfFile: lrcPath, encoding: .utf8) {
            lrcLines = LrcParser.parse(lrcStr)
            lrcTableView.reloadData()
        } else if let url = URL(string: lrcPath) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let lrcStr = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self?.lrcLines = LrcParser.parse(lrcStr)
                        self?.lrcTableView.reloadData()
                    }
                }
            }.resume()
        }
    }

    private func updateLrcIndex(at time: TimeInterval) {
        guard !lrcLines.isEmpty else { return }
        var newIndex = -1
        for (i, line) in lrcLines.enumerated() {
            if line.time <= time { newIndex = i } else { break }
        }
        if newIndex != currentLrcIndex {
            currentLrcIndex = newIndex
            lrcTableView.reloadData()
            if showingLrc { scrollToCurrentLrc(animated: true) }
        }
    }

    private func scrollToCurrentLrc(animated: Bool) {
        guard currentLrcIndex >= 0, currentLrcIndex < lrcLines.count else { return }
        lrcTableView.scrollToRow(at: IndexPath(row: currentLrcIndex, section: 0), at: .middle, animated: animated)
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
                self?.updateLrcIndex(at: current)
            }
        }
        player.onSongChange = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateUI()
                self?.loadLrc()
                self?.currentLrcIndex = -1
            }
        }
    }

    private func updateUI() {
        guard let song = player.currentSong else {
            titleLabel.text = "未播放"; artistLabel.text = ""; coverImageView.image = nil; return
        }
        titleLabel.text = song.name
        artistLabel.text = song.singer
        playBtn.setImage(UIImage(systemName: player.isPlaying ? "pause.fill" : "play.fill"), for: .normal)
        modeBtn.setImage(UIImage(systemName: player.playMode == .listLoop ? "repeat" : player.playMode == .singleLoop ? "repeat.1" : "shuffle"), for: .normal)
        modeBtn.tintColor = player.playMode == .listLoop ? UIColor.white.withAlphaComponent(0.7) : .systemPink

        let coverUrl = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.png").path : song.coverUrl
        if FileManager.default.fileExists(atPath: coverUrl), let img = UIImage(contentsOfFile: coverUrl) {
            coverImageView.image = img; backgroundImageView.image = img
        } else if let url = URL(string: coverUrl) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                if let data = data, let img = UIImage(data: data) {
                    DispatchQueue.main.async { self?.coverImageView.image = img; self?.backgroundImageView.image = img }
                }
            }.resume()
        }
        downloadBtn.isHidden = song.isLocal
        downloadBtn.setImage(UIImage(systemName: song.isLocal ? "checkmark.circle.fill" : "arrow.down.circle"), for: .normal)
        downloadBtn.tintColor = song.isLocal ? .systemGreen : UIColor.white.withAlphaComponent(0.7)
    }

    @objc private func onSliderChange() { player.seek(to: TimeInterval(progressSlider.value) * player.duration) }
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
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

extension PlayerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIButton { return false }
        if touch.view is UISlider { return false }
        return true
    }
}

extension PlayerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { lrcLines.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LrcCell", for: indexPath) as! LrcCell
        cell.configure(text: lrcLines[indexPath.row].text, isCurrent: indexPath.row == currentLrcIndex)
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 44 }
}

class LrcCell: UITableViewCell {
    private let lrcLabel = UILabel()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        lrcLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
        lrcLabel.autoresizingMask = [.flexibleWidth]
        lrcLabel.textAlignment = .center
        lrcLabel.font = .systemFont(ofSize: 16)
        lrcLabel.textColor = UIColor.white.withAlphaComponent(0.5)
        lrcLabel.numberOfLines = 0
        contentView.addSubview(lrcLabel)
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(text: String, isCurrent: Bool) {
        lrcLabel.text = text
        lrcLabel.textColor = isCurrent ? .systemPink : UIColor.white.withAlphaComponent(0.5)
        lrcLabel.font = isCurrent ? .systemFont(ofSize: 18, weight: .semibold) : .systemFont(ofSize: 16)
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        lrcLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 44)
    }
}
