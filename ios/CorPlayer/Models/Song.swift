import Foundation

struct Song: Codable, Equatable {
    let id: String
    let name: String
    let singer: String
    let album: String
    let coverUrl: String
    let mp3Url: String
    let lrcUrl: String
    let duration: TimeInterval
    var localPath: String?  // 下载到本地后的路径
    var isLocal: Bool { localPath != nil }

    enum CodingKeys: String, CodingKey {
        case id, name, singer, album, coverUrl = "cover", mp3Url = "mp3", lrcUrl = "lrc", duration, localPath
    }

    static func == (lhs: Song, rhs: Song) -> Bool { lhs.id == rhs.id }
}

struct CoreConfig: Codable {
    let name: String?
    let singer: String?
    let album: String?
    let type: String?
    let mp3: String?
    let cover: String?
    let lrc: String?
    let url: String?  // 云端重定向URL
    let duration: TimeInterval?
}
