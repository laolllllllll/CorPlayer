import UIKit

class MeViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var tableView: UITableView!
    private var localSongs: [Song] = []
    private let player = PlayerManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "我的"
        view.backgroundColor = .black
        setupTableView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        localSongs = CoresDownloader.shared.getLocalSongs()
        tableView.reloadData()
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .black
        tableView.rowHeight = 60
        tableView.register(LocalSongCell.self, forCellReuseIdentifier: "LocalSongCell")
        view.addSubview(tableView)
    }

    func numberOfSections(in tableView: UITableView) -> Int { return 4 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "播放设置"
        case 1: return localSongs.isEmpty ? nil : "本地音乐 (\(localSongs.count))"
        case 2: return "关于"
        case 3: return "设置"
        default: return ""
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return max(localSongs.count, 1)
        case 2: return 1
        case 3: return 2
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
            cell.textLabel?.text = "播放模式"
            cell.textLabel?.textColor = .white
            cell.detailTextLabel?.text = playModeText()
            cell.detailTextLabel?.textColor = .systemPink
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        if indexPath.section == 1 {
            if localSongs.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
                cell.textLabel?.text = "暂无本地音乐"
                cell.textLabel?.textColor = UIColor.white.withAlphaComponent(0.5)
                cell.textLabel?.textAlignment = .center
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocalSongCell", for: indexPath) as! LocalSongCell
            cell.configure(song: localSongs[indexPath.row])
            return cell
        }
        if indexPath.section == 2 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
            cell.textLabel?.text = "CorPlayer"
            cell.textLabel?.textColor = .white
            cell.detailTextLabel?.text = "v2.0"
            cell.detailTextLabel?.textColor = UIColor.white.withAlphaComponent(0.6)
            cell.selectionStyle = .none
            return cell
        }
        if indexPath.section == 3 {
            if indexPath.row == 0 {
                let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
                cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
                cell.textLabel?.text = "首页链接"
                cell.textLabel?.textColor = .white
                let currentURL = UserDefaults.standard.string(forKey: "corplayer_home_url") ?? "默认"
                cell.detailTextLabel?.text = currentURL == "https://laolllllllll.github.io/CorPlayer/app/index.html" ? "默认" : "自定义"
                cell.detailTextLabel?.textColor = .systemPink
                cell.accessoryType = .disclosureIndicator
                return cell
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
                cell.textLabel?.text = "恢复默认首页"
                cell.textLabel?.textColor = .systemRed
                cell.textLabel?.textAlignment = .center
                return cell
            }
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let mode = player.switchPlayMode()
            let alert = UIAlertController(title: "播放模式", message: modeText(mode), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            present(alert, animated: true)
            tableView.reloadRows(at: [indexPath], with: .none)
        } else if indexPath.section == 1, !localSongs.isEmpty {
            player.setQueue(localSongs, playAt: indexPath.row)
        } else if indexPath.section == 3 {
            if indexPath.row == 0 {
                showHomeURLSetting()
            } else {
                UserDefaults.standard.removeObject(forKey: "corplayer_home_url")
                showAlert(title: "已恢复默认", message: "重启APP后生效")
                tableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete, indexPath.section == 1, indexPath.row < localSongs.count {
            let song = localSongs[indexPath.row]
            CoresDownloader.shared.removeLocalSong(song)
            localSongs = CoresDownloader.shared.getLocalSongs()
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "删除"
    }

    private func showHomeURLSetting() {
        let alert = UIAlertController(title: "设置首页链接", message: "请输入新的首页链接，必须以 .html 结尾", preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://example.com/index.html"
            field.text = UserDefaults.standard.string(forKey: "corplayer_home_url") ?? ""
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            guard let url = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !url.isEmpty else { return }
            if !url.lowercased().hasSuffix(".html") {
                self.showAlert(title: "格式错误", message: "首页链接必须以 .html 结尾")
                return
            }
            UserDefaults.standard.set(url, forKey: "corplayer_home_url")
            self.showAlert(title: "保存成功", message: "重启APP后生效\n新首页: \(url)")
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func playModeText() -> String { modeText(player.playMode) }
    private func modeText(_ mode: PlayerManager.PlayMode) -> String {
        switch mode {
        case .listLoop: return "列表循环"
        case .singleLoop: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }
}

class LocalSongCell: UITableViewCell {
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
        selectionStyle = .none

        coverView.frame = CGRect(x: 16, y: 8, width: 44, height: 44)
        coverView.layer.cornerRadius = 8
        coverView.clipsToBounds = true
        coverView.backgroundColor = .systemGray4
        coverView.contentMode = .scaleAspectFill
        contentView.addSubview(coverView)

        titleLabel.frame = CGRect(x: 72, y: 10, width: 200, height: 22)
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 72, y: 34, width: 200, height: 18)
        artistLabel.font = .systemFont(ofSize: 13)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        contentView.addSubview(artistLabel)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(song: Song) {
        titleLabel.text = song.name
        artistLabel.text = song.singer
        let coverPath = URL(fileURLWithPath: song.localPath ?? "").deletingLastPathComponent().appendingPathComponent("info.png").path
        if FileManager.default.fileExists(atPath: coverPath), let img = UIImage(contentsOfFile: coverPath) {
            coverView.image = img
        }
    }
}
