import UIKit

class QueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private var tableView: UITableView!
    private let player = PlayerManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "播放队列"
        view.backgroundColor = .black
        setupTableView()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearQueue))
        navigationItem.rightBarButtonItem?.tintColor = .systemPink
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .black
        tableView.rowHeight = 64
        tableView.register(QueueCell.self, forCellReuseIdentifier: "QueueCell")
        view.addSubview(tableView)
    }

    @objc private func clearQueue() {
        let alert = UIAlertController(title: "清空队列", message: "确定清空播放队列？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .destructive) { _ in
            self.player.clearQueue()
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return player.queue.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return player.queue.isEmpty ? nil : "\(player.queue.count) 首歌曲"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "QueueCell", for: indexPath) as! QueueCell
        let song = player.queue[indexPath.row]
        cell.configure(song: song, index: indexPath.row, isCurrent: indexPath.row == player.currentIndex)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        player.setQueue(player.queue, playAt: indexPath.row)
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            player.removeFromQueue(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        player.moveSong(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return "移除"
    }
}

class QueueCell: UITableViewCell {
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let playingIndicator = UIActivityIndicatorView(style: .medium)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.14, alpha: 0.8)
        selectionStyle = .none

        coverView.frame = CGRect(x: 16, y: 10, width: 44, height: 44)
        coverView.layer.cornerRadius = 8
        coverView.clipsToBounds = true
        coverView.backgroundColor = .systemGray4
        coverView.contentMode = .scaleAspectFill
        contentView.addSubview(coverView)

        titleLabel.frame = CGRect(x: 72, y: 12, width: 200, height: 22)
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 72, y: 36, width: 200, height: 18)
        artistLabel.font = .systemFont(ofSize: 13)
        artistLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        contentView.addSubview(artistLabel)

        playingIndicator.frame = CGRect(x: UIScreen.main.bounds.width - 60, y: 20, width: 24, height: 24)
        playingIndicator.hidesWhenStopped = true
        contentView.addSubview(playingIndicator)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(song: Song, index: Int, isCurrent: Bool) {
        titleLabel.text = song.name
        titleLabel.textColor = isCurrent ? .systemPink : .label
        artistLabel.text = song.singer
        if isCurrent && PlayerManager.shared.isPlaying {
            playingIndicator.startAnimating()
            playingIndicator.color = .systemPink
        } else {
            playingIndicator.stopAnimating()
        }
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
}
