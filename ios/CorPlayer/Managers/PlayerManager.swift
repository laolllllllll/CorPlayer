import Foundation
import AVFoundation
import UIKit

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private(set) var queue: [Song] = []
    private(set) var currentIndex: Int = -1
    private var timeObserver: Any?
    private var lrcLines: [(time: TimeInterval, text: String)] = []
    private let queueLock = NSLock()

    enum PlayMode { case listLoop, singleLoop, shuffle }
    var playMode: PlayMode = .listLoop

    var currentSong: Song? {
        queueLock.lock()
        defer { queueLock.unlock() }
        guard currentIndex >= 0 && currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var isPlaying: Bool { player?.rate ?? 0 > 0 }
    var currentTime: TimeInterval { player?.currentTime().seconds ?? 0 }
    var duration: TimeInterval { playerItem?.duration.seconds ?? 0 }

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

    func setQueue(_ songs: [Song], playAt index: Int = 0) {
        queueLock.lock()
        queue = songs
        currentIndex = index
        queueLock.unlock()
        if let song = currentSong { play(song: song) }
    }

    func addToQueue(_ song: Song) {
        queueLock.lock()
        queue.append(song)
        queueLock.unlock()
    }

    func removeFromQueue(at index: Int) {
        queueLock.lock()
        guard index >= 0 && index < queue.count else { queueLock.unlock(); return }
        queue.remove(at: index)
        if index < currentIndex { currentIndex -= 1 }
        else if index == currentIndex {
            queueLock.unlock()
            next()
            return
        }
        queueLock.unlock()
    }

    func clearQueue() {
        queueLock.lock()
        queue.removeAll()
        currentIndex = -1
        queueLock.unlock()
        DispatchQueue.main.async {
            self.player?.pause()
            self.player = nil
            self.playerItem = nil
            self.onSongChange?(nil)
        }
    }

    func moveSong(from: Int, to: Int) {
        queueLock.lock()
        guard from >= 0, from < queue.count, to >= 0, to < queue.count else { queueLock.unlock(); return }
        let song = queue.remove(at: from)
        queue.insert(song, at: to)
        if from == currentIndex { currentIndex = to }
        else if from < currentIndex && to >= currentIndex { currentIndex -= 1 }
        else if from > currentIndex && to <= currentIndex { currentIndex += 1 }
        queueLock.unlock()
    }

    func replaceSong(at index: Int, with song: Song) {
        queueLock.lock()
        guard index >= 0, index < queue.count else { queueLock.unlock(); return }
        queue[index] = song
        queueLock.unlock()
        if index == currentIndex { onSongChange?(song) }
    }

    func play(song: Song) {
        DispatchQueue.main.async {
            var urlString = song.isLocal ? song.localPath ?? "" : song.mp3Url
            if !song.isLocal {
                if let decoded = urlString.removingPercentEncoding { urlString = decoded }
                let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed)
                if let encoded = urlString.addingPercentEncoding(withAllowedCharacters: allowed) { urlString = encoded }
            }
            guard let url = song.isLocal ? URL(fileURLWithPath: urlString) : URL(string: urlString) else {
                print("PlayerManager: invalid URL - \(urlString)")
                return
            }
            if let observer = self.timeObserver {
                self.player?.removeTimeObserver(observer)
                self.timeObserver = nil
            }
            NotificationCenter.default.removeObserver(self)
            self.playerItem?.removeObserver(self, forKeyPath: "status")
            self.playerItem?.removeObserver(self, forKeyPath: "duration")

            self.player?.pause()
            self.playerItem = AVPlayerItem(url: url)
            self.player = AVPlayer(playerItem: self.playerItem)

            self.playerItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.songDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: self.playerItem)

            self.player?.play()
            self.loadLrc(for: song)
            self.setupTimeObserver()
            self.onSongChange?(song)
            self.onStateChange?(true)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueObservedChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem, item.status == .failed {
            print("PlayerManager: play failed - \(item.error?.localizedDescription ?? "unknown")")
        }
    }

    func play() {
        DispatchQueue.main.async {
            if self.currentSong == nil, !self.queue.isEmpty {
                self.queueLock.lock()
                self.currentIndex = 0
                self.queueLock.unlock()
                if let song = self.currentSong { self.play(song: song) }
            } else {
                self.player?.play()
                self.onStateChange?(true)
            }
        }
    }

    func pause() {
        DispatchQueue.main.async {
            self.player?.pause()
            self.onStateChange?(false)
        }
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func next() {
        DispatchQueue.main.async {
            guard !self.queue.isEmpty else { return }
            self.queueLock.lock()
            switch self.playMode {
            case .shuffle: self.currentIndex = Int.random(in: 0..<self.queue.count)
            case .singleLoop: break
            case .listLoop: self.currentIndex = (self.currentIndex + 1) % self.queue.count
            }
            let idx = self.currentIndex
            self.queueLock.unlock()
            if idx >= 0 && idx < self.queue.count { self.play(song: self.queue[idx]) }
        }
    }

    func previous() {
        DispatchQueue.main.async {
            guard !self.queue.isEmpty else { return }
            if self.currentTime > 3 { self.seek(to: 0); return }
            self.queueLock.lock()
            self.currentIndex = (self.currentIndex - 1 + self.queue.count) % self.queue.count
            let idx = self.currentIndex
            self.queueLock.unlock()
            if idx >= 0 && idx < self.queue.count { self.play(song: self.queue[idx]) }
        }
    }

    func seek(to time: TimeInterval) {
        DispatchQueue.main.async {
            self.player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        }
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
        DispatchQueue.main.async {
            switch self.playMode {
            case .singleLoop:
                self.seek(to: 0)
                self.player?.play()
            case .listLoop, .shuffle:
                self.next()
            }
        }
    }

    private func setupTimeObserver() {
        guard let player = player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.onProgress?(time.seconds, self.duration)
            self.updateLrc(at: time.seconds)
        }
    }

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
        DispatchQueue.global(qos: .background).async {
            var text: String?
            if FileManager.default.fileExists(atPath: path) {
                text = try? String(contentsOfFile: path, encoding: .utf8)
            } else if let url = URL(string: path) {
                if let data = try? Data(contentsOf: url, options: .mappedIfSafe) {
                    text = String(data: data, encoding: .utf8)
                }
            }
            if let text = text { self.lrcLines = LrcParser.parse(text) }
        }
    }

    private func updateLrc(at time: TimeInterval) {
        guard !lrcLines.isEmpty else { return }
        var currentText = ""
        for line in lrcLines {
            if line.time <= time { currentText = line.text } else { break }
        }
        onLrcUpdate?(currentText)
    }

    deinit {
        if let observer = timeObserver { player?.removeTimeObserver(observer) }
        NotificationCenter.default.removeObserver(self)
    }
}
