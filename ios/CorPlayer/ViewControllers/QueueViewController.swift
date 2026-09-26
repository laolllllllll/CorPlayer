import UIKit

class QueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var tableView: UITableView!
    private let player = PlayerManager.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "播放队列"
        view.backgroundColor = .black
        setupTableView()
        setupObservers()
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
        tableView.separatorColor = .darkGray
        tableView.rowHeight = 60
        tableView.register(QueueCell.self, forCellReuseIdentifier: "QueueCell")
        view.addSubview(tableView)

        // 导航栏按钮
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "清空", style: .plain, target: self, action: #selector(clearQueue))
    }

    private func setupObservers() {
        player.onSongChange = { [weak self] _ in
            DispatchQueue.main.async { self?.tableView.reloadData() }
        }
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

    // MARK: - UITableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return player.queue.count
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

// MARK: - Cell
class QueueCell: UITableViewCell {
    private let idxLabel = UILabel()
    private let titleLabel = UILabel()
    private let artistLabel = UILabel()
    private let localBadge = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .black
        selectionStyle = .none

        idxLabel.frame = CGRect(x: 12, y: 0, width: 30, height: 60)
        idxLabel.font = .systemFont(ofSize: 14)
        idxLabel.textColor = .darkGray
        idxLabel.textAlignment = .center
        contentView.addSubview(idxLabel)

        titleLabel.frame = CGRect(x: 50, y: 10, width: 250, height: 22)
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)

        artistLabel.frame = CGRect(x: 50, y: 34, width: 200, height: 18)
        artistLabel.font = .systemFont(ofSize: 12)
        artistLabel.textColor = .gray
        contentView.addSubview(artistLabel)

        localBadge.frame = CGRect(x: UIScreen.main.bounds.width - 60, y: 20, width: 45, height: 20)
        localBadge.font = .systemFont(ofSize: 10)
        localBadge.textColor = .systemGreen
        localBadge.textAlignment = .right
        contentView.addSubview(localBadge)
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(song: Song, index: Int, isCurrent: Bool) {
        idxLabel.text = isCurrent ? "▶" : "\(index + 1)"
        idxLabel.textColor = isCurrent ? .systemRed : .darkGray
        titleLabel.text = song.name
        titleLabel.textColor = isCurrent ? .systemRed : .white
        artistLabel.text = song.singer
        localBadge.text = song.isLocal ? "本地" : ""
    }
}
