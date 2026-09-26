import Foundation
import AVFoundation
import UIKit

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    private var player: AVPlayer?
    private(set) var queue: [Song] = []
    private(set) var currentIndex: Int = -1
    private var timeObserver: Any?
    private var lrcLines: [(time: TimeInterval, text: String)] = []

    enum PlayMode { case listLoop, singleLoop, shuffle }
    var playMode: PlayMode = .listLoop

    var currentSong: Song? {
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var isPlaying: Bool { player?.rate ?? 0 > 0 }
    var currentTime: TimeInterval { player?.currentTime().seconds ?? 0 }
    var duration: TimeInterval { player?.currentItem?.duration.seconds ?? 0 }

    // 回调
    var onStateChange: ((Bool) -> Void)?
    var onProgress: ((TimeInterval, TimeInterval) -> Void)?
    var onSongChange: ((Song?) -> Void)?
    var onLrcUpdate: ((String) -> Void)?

    private override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("AudioSession error: \(error)") }
    }

    // MARK: - 队列操作
    func setQueue(_ songs: [Song], playAt index: Int = 0) {
        queue = songs
        currentIndex = index
        if let song = currentSong {
            play(song: song)
        }
    }

    func addToQueue(_ song: Song) {
        queue.append(song)
    }

    func removeFromQueue(at index: Int) {
        guard index >= 0 && index < queue.count else { return }
        queue.remove(at: index)
        if index < currentIndex { currentIndex -= 1 }
        else if index == currentIndex { next() }
    }

    func clearQueue() {
        queue.removeAll()
        currentIndex = -1
        player?.pause()
        player = nil
        onSongChange?(nil)
    }

    func moveSong(from: Int, to: Int) {
        guard from >= 0, from < queue.count, to >= 0, to < queue.count else { return }
        let song = queue.remove(at: from)
        queue.insert(song, at: to)
        if from == currentIndex { currentIndex = to }
        else if from < currentIndex && to >= currentIndex { currentIndex -= 1 }
        else if from > currentIndex && to <= currentIndex { currentIndex += 1 }
    }

    // MARK: - 播放控制
    func play(song: Song) {
        guard let url = song.isLocal ? URL(fileURLWithPath: song.localPath ?? "") : URL(string: song.mp3Url) else { return }
        player?.pause()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        loadLrc(for: song)
        setupTimeObserver()
        onSongChange?(song)
        onStateChange?(true)
        NotificationCenter.default.removeObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(songDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)
    }

    func play() {
        if currentSong == nil, !queue.isEmpty {
            currentIndex = 0
            if let song = currentSong { play(song: song) }
        } else {
            player?.play()
            onStateChange?(true)
        }
    }

    func pause() {
        player?.pause()
        onStateChange?(false)
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func next() {
        guard !queue.isEmpty else { return }
        switch playMode {
        case .shuffle:
            currentIndex = Int.random(in: 0..<queue.count)
        case .singleLoop:
            break // 单曲循环不换歌
        case .listLoop:
            currentIndex = (currentIndex + 1) % queue.count
        }
        if let song = currentSong { play(song: song) }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 { seek(to: 0); return }
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        if let song = currentSong { play(song: song) }
    }

    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
    }

    func switchPlayMode() -> PlayMode {
        switch playMode {
        case .listLoop: playMode = .singleLoop
        case .singleLoop: playMode = .shuffle
        case .shuffle: playMode = .listLoop
        }
        return playMode
    }

    @objc private func songDidEnd() {
        switch playMode {
        case .singleLoop:
            seek(to: 0); player?.play()
        case .listLoop, .shuffle:
            next()
        }
    }

    private func setupTimeObserver() {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.onProgress?(time.seconds, self.duration)
            self.updateLrc(at: time.seconds)
        }
    }

    // MARK: - 歌词
    private func loadLrc(for song: Song) {
        lrcLines.removeAll()
        let lrcPath: String?
        if song.isLocal, let local = song.localPath {
            let dir = (local as NSString).deletingLastPathComponent
            lrcPath = (dir as NSString).appendingPathComponent("info.lrc")
        } else {
            lrcPath = song.lrcUrl
        }
        guard let path = lrcPath, !path.isEmpty else { return }
        DispatchQueue.global().async {
            if let url = URL(string: path), let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                self.lrcLines = LrcParser.parse(text)
            } else if FileManager.default.fileExists(atPath: path), let text = try? String(contentsOfFile: path, encoding: .utf8) {
                self.lrcLines = LrcParser.parse(text)
            }
        }
    }

    private func updateLrc(at time: TimeInterval) {
        guard !lrcLines.isEmpty else { return }
        var currentText = ""
        for line in lrcLines {
            if line.time <= time { currentText = line.text }
            else { break }
        }
        onLrcUpdate?(currentText)
    }
}
