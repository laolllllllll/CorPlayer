import Foundation
import UIKit

class CoresDownloader {
    static let shared = CoresDownloader()

    private var localDir: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Cores", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 解析 .core URL，递归处理云端重定向，最终返回 Song
    func resolveCore(url coreUrl: String, completion: @escaping (Result<Song, Error>) -> Void) {
        let url = coreUrl.hasSuffix("/") ? coreUrl : coreUrl + "/"
        resolveRecursive(url: url, depth: 0, completion: completion)
    }

    private func resolveRecursive(url: String, depth: Int, completion: @escaping (Result<Song, Error>) -> Void) {
        guard depth < 5 else {
            completion(.failure(NSError(domain: "CoresDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "重定向层数过多"])))
            return
        }
        // 下载config.json
        let configUrl = url + "config.json"
        downloadFile(url: configUrl) { result in
            switch result {
            case .success(let data):
                guard let config = try? JSONDecoder().decode(CoreConfig.self, from: data) else {
                    completion(.failure(NSError(domain: "CoresDownloader", code: -2, userInfo: [NSLocalizedDescriptionKey: "config.json解析失败"])))
                    return
                }
                // 如果有url字段，继续向下解析
                if let redirectUrl = config.url, !redirectUrl.isEmpty {
                    var nextUrl = redirectUrl
                    if !nextUrl.hasSuffix("/") { nextUrl += "/" }
                    self.resolveRecursive(url: nextUrl, depth: depth + 1, completion: completion)
                    return
                }
                // 标准.core：构建Song
                let song = Song(
                    id: UUID().uuidString,
                    name: config.name ?? "未知歌曲",
                    singer: config.singer ?? "未知歌手",
                    album: config.album ?? "",
                    coverUrl: url + "info.png",
                    mp3Url: url + "info.mp3",
                    lrcUrl: url + "info.lrc",
                    duration: config.duration ?? 0,
                    localPath: nil
                )
                completion(.success(song))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 下载 .core 到本地
    func downloadCore(song: Song, progress: @escaping (Double) -> Void, completion: @escaping (Result<Song, Error>) -> Void) {
        let songDir = localDir.appendingPathComponent("\(song.singer) - \(song.name).core", isDirectory: true)
        try? FileManager.default.createDirectory(at: songDir, withIntermediateDirectories: true)

        let group = DispatchGroup()
        var downloadError: Error?

        // 下载info.mp3
        group.enter()
        downloadFile(url: song.mp3Url, progress: { p in progress(p * 0.8) }) { result in
            switch result {
            case .success(let data):
                try? data.write(to: songDir.appendingPathComponent("info.mp3"))
            case .failure(let e): downloadError = e
            }
            group.leave()
        }

        // 下载info.png
        group.enter()
        downloadFile(url: song.coverUrl) { result in
            if case .success(let data) = result {
                try? data.write(to: songDir.appendingPathComponent("info.png"))
            }
            group.leave()
        }

        // 下载info.lrc
        group.enter()
        downloadFile(url: song.lrcUrl) { result in
            if case .success(let data) = result {
                try? data.write(to: songDir.appendingPathComponent("info.lrc"))
            }
            group.leave()
        }

        // 写config.json
        let config = CoreConfig(name: song.name, singer: song.singer, album: song.album, type: "song", mp3: "info.mp3", cover: "info.png", lrc: "info.lrc", url: nil, duration: song.duration)
        if let configData = try? JSONEncoder().encode(config) {
            try? configData.write(to: songDir.appendingPathComponent("config.json"))
        }

        group.notify(queue: .main) {
            progress(1.0)
            if let error = downloadError {
                completion(.failure(error))
            } else {
                var localSong = song
                localSong.localPath = songDir.appendingPathComponent("info.mp3").path
                self.saveLocalSong(localSong)
                completion(.success(localSong))
            }
        }
    }

    // MARK: - 本地存储
    private var localSongsPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("local_songs.json")
    }

    func getLocalSongs() -> [Song] {
        guard let data = try? Data(contentsOf: localSongsPath),
              let songs = try? JSONDecoder().decode([Song].self, from: data) else { return [] }
        return songs
    }

    func saveLocalSong(_ song: Song) {
        var songs = getLocalSongs()
        if !songs.contains(song) { songs.append(song) }
        try? JSONEncoder().encode(songs).write(to: localSongsPath)
    }

    func removeLocalSong(_ song: Song) {
        var songs = getLocalSongs()
        songs.removeAll { $0 == song }
        try? JSONEncoder().encode(songs).write(to: localSongsPath)
        // 删除本地文件
        if let path = song.localPath {
            let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
            try? FileManager.default.removeItem(at: dir)
        }
    }

    // MARK: - 基础下载
    private func downloadFile(url: String, progress: ((Double) -> Void)? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        // 确保URL正确编码（处理中文等特殊字符）
        var safeUrl = url
        if let decoded = safeUrl.removingPercentEncoding {
            safeUrl = decoded
        }
        let allowed = CharacterSet.urlFragmentAllowed.union(.urlQueryAllowed).union(.urlPathAllowed).union(.urlHostAllowed).union(.urlUserAllowed).union(.urlPasswordAllowed)
        if let encoded = safeUrl.addingPercentEncoding(withAllowedCharacters: allowed) {
            safeUrl = encoded
        }
        guard let urlObj = URL(string: safeUrl) else {
            completion(.failure(NSError(domain: "CoresDownloader", code: -3, userInfo: [NSLocalizedDescriptionKey: "无效URL: \(safeUrl)"])))
            return
        }
        let session = URLSession.shared
        let task = session.dataTask(with: urlObj) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data else {
                completion(.failure(NSError(domain: "CoresDownloader", code: -4, userInfo: [NSLocalizedDescriptionKey: "无数据"])))
                return
            }
            progress?(1.0)
            completion(.success(data))
        }
        task.resume()
    }
}
