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
        tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .black
        tableView.separatorColor = .darkGray
        tableView.rowHeight = 60
        tableView.register(LocalSongCell.self, forCellReuseIdentifier: "LocalSongCell")
        view.addSubview(tableView)
    }

    // MARK: - Sections
    func numberOfSections(in tableView: UITableView) -> Int { return 3 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "播放设置"
        case 1: return "本地音乐 (\(localSongs.count))"
        case 2: return "关于"
        default: return ""
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .gray
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return max(localSongs.count, 1)
        case 2: return 1
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
            cell.backgroundColor = .black
            cell.textLabel?.text = "播放模式"
            cell.textLabel?.textColor = .white
            cell.detailTextLabel?.text = playModeText()
            cell.detailTextLabel?.textColor = .systemRed
            cell.accessoryType = .disclosureIndicator
            return cell
        }
        if indexPath.section == 1 {
            if localSongs.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.backgroundColor = .black
                cell.textLabel?.text = "暂无本地音乐"
                cell.textLabel?.textColor = .darkGray
                cell.textLabel?.textAlignment = .center
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocalSongCell", for: indexPath) as! LocalSongCell
            cell.configure(song: localSongs[indexPath.row])
            return cell
        }
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = .black
        cell.textLabel?.text = "CorPlayer"
        cell.textLabel?.textColor = .white
        cell.detailTextLabel?.text = "v1.0"
        cell.detailTextLabel?.textColor = .gray
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let mode = player.switchPlayMode()
            showAlert(title: "播放模式", message: modeText(mode))
            tableView.reloadRows(at: [indexPath], with: .none)
        } else if indexPath.section == 1, !localSongs.isEmpty {
            player.setQueue(localSongs, playAt: indexPath.row)
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

    private func playModeText() -> String { modeText(player.playMode) }

    private func modeText(_ mode: PlayerManager.PlayMode) -> String {
        switch mode {
        case .listLoop: return "列表循环"
        case .singleLoop: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Cell
class LocalSongCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let localBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .black
        selectionStyle = .none

        titleLabel.frame = CGRect(x: 16, y: 10, width: 250, height: 22)
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 16, y: 34, width: 200, height: 18)
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .gray
        contentView.addSubview(artistLabel)

        localBadge.frame = CGRect(x: UIScreen.main.bounds.width - 60, y: 20, width: 45, height: 20)
        localBadge.font = .systemFont(ofSize: 10)
        localBadge.textColor = .systemGreen
        localBadge.text = "本地"
        localBadge.textAlignment = .right
        contentView.addSubview(localBadge)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(song: Song) {
        titleLabel.text = song.name
        artistLabel.text = song.singer
    }
}
