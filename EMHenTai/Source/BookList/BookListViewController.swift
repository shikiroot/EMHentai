//
//  BookListViewController.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/14.
//

import Foundation
import UIKit
import Kingfisher

class BookListViewController: UITableViewController {
    enum ListType {
        case Home
        case History
        case Download
    }
    
    private let type: ListType
    
    private var searchInfo: SearchInfo?
    private var books = [Book]()
    private var hasMore = true
    
    private let footerView = BookListFooterView()
    
    init(type: ListType) {
        self.type = type
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConfig()
        setupData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if type != .Home {
            self.refreshData(with: nil)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 150
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.tableFooterView = footerView
        tableView.register(BookListTableViewCell.self, forCellReuseIdentifier: NSStringFromClass(BookListTableViewCell.self))
        
        if type == .Home {
            refreshControl = UIRefreshControl()
            refreshControl?.attributedTitle = NSAttributedString(string: "刷新中...")
            refreshControl?.addTarget(self, action: #selector(setupData), for: .valueChanged)
        }
        
        switch type {
        case .Home:
            navigationItem.title = "主页"
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(tapNavBarRightItem))
        case .History:
            navigationItem.title = "历史"
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "clear"), style: .plain, target: self, action: #selector(tapNavBarRightItem))
        case .Download:
            navigationItem.title = "下载"
        }
    }
    
    private func setupConfig() {
        if type == .Home {
            SearchManager.shared.delegate = self
        }
    }
    
    @objc
    private func setupData() {
        switch type {
        case .Home:
            refreshData(with: SearchInfo())
        case .History:
            refreshData(with: nil)
        case .Download:
            refreshData(with: nil)
        }
    }
}

// MARK: SearchManagerCallbackDelegate
extension BookListViewController: SearchManagerCallbackDelegate {
    @MainActor
    func searchStartCallback(searchInfo: SearchInfo) async {
        guard searchInfo.pageIndex == 0 else { return }
        self.tableView.setContentOffset(CGPoint(x: 0, y: -self.refreshControl!.frame.size.height * 3), animated: false)
        self.refreshControl?.beginRefreshing()
    }
    
    @MainActor
    func searchFinishCallback(searchInfo: SearchInfo, result: Result<[Book], SearchError>) async {
        switch result {
        case .success(let books):
            self.hasMore = !books.isEmpty
            if searchInfo.pageIndex == 0 {
                self.books = books
                if !self.tableView.visibleCells.isEmpty {
                    self.tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
                }
            } else {
                self.books += books
            }
            self.searchInfo = searchInfo
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
            if !self.hasMore {
                self.footerView.hint = self.books.isEmpty ? .noData : .noMoreData
            } else {
                self.footerView.hint = .empty
            }
        case .failure:
            self.footerView.hint = .netError
        }
    }
}

// MARK: load Data
extension BookListViewController {
    private func refreshData(with searchInfo: SearchInfo?) {
        switch type {
        case .Home:
            guard let searchInfo = searchInfo else { return }
            SearchManager.shared.searchWith(info: searchInfo)
        case .History, .Download:
            books = (type == .History) ? DBManager.shared.booksMap[.history]! : DBManager.shared.booksMap[.download]!
            if (type == .History) { navigationItem.rightBarButtonItem?.isEnabled = !books.isEmpty }
            hasMore = false
            footerView.hint = books.isEmpty ? .noData : .noMoreData
            self.tableView.reloadData()
        }
    }
    
    private func loadMoreData() {
        guard type == .Home, let searchInfo = searchInfo, hasMore else { return }
        var nextInfo = searchInfo
        nextInfo.pageIndex += 1
        SearchManager.shared.searchWith(info: nextInfo)
    }
}

// MARK: TapNavBarRightItem
extension BookListViewController {
    @objc
    private func tapNavBarRightItem() {
        switch type {
        case .Home:
            navigationController?.pushViewController(SearchViewController(), animated: true)
        case .History:
            guard !books.isEmpty else { return }
            let vc = UIAlertController(title: "提示", message: "确定要清除所有历史记录吗？\n(不会影响已下载内容)", preferredStyle: .alert)
            vc.addAction(UIAlertAction(title: "清除", style: .default, handler: { _ in
                DBManager.shared.booksMap[.history]!
                    .filter { !DBManager.shared.contains(book: $0, type: .download) }
                    .forEach { DownloadManager.shared.remove(book: $0) }
                DBManager.shared.removeAll(type: .history)
                self.refreshData(with: nil)
            }))
            vc.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
            present(vc, animated: true, completion: nil)
        case .Download:
            break
        }
    }
}

// MARK: AlertVC
extension BookListViewController {
    private func makeAlertVC(with book: Book) -> UIAlertController {
        let vc = UIAlertController(title: "", message: book.showTitle, preferredStyle: .alert)
        
        if !DBManager.shared.contains(book: book, type: .download) {
            vc.addAction(UIAlertAction(title: "下载", style: .default, handler: { _ in
                DownloadManager.shared.download(book: book)
                DBManager.shared.insertIfNotExist(book: book, at: .download)
                self.tableView.reloadData()
            }))
        } else {
            switch DownloadManager.shared.downloadState(of: book) {
            case .before, .suspend:
                vc.addAction(UIAlertAction(title: "下载", style: .default, handler: { _ in
                    DownloadManager.shared.download(book: book)
                }))
            case .ing:
                vc.addAction(UIAlertAction(title: "暂停", style: .default, handler: { _ in
                    DownloadManager.shared.suspend(book: book)
                }))
            case .finish:
                if type != .History {
                    vc.addAction(UIAlertAction(title: "删除下载", style: .default, handler: { _ in
                        DownloadManager.shared.remove(book: book)
                        DBManager.shared.remove(book: book, at: .download)
                        if self.type == .Download { self.refreshData(with: nil) }
                    }))
                }
            }
        }
        
        if type == .History {
            vc.addAction(UIAlertAction(title: "删除历史", style: .default, handler: { _ in
                if !DBManager.shared.contains(book: book, type: .download) {
                    DownloadManager.shared.remove(book: book)
                }
                DBManager.shared.remove(book: book, at: .history)
                self.refreshData(with: nil)
            }))
        }
        
        if !book.tags.isEmpty {
            vc.addAction(UIAlertAction(title: "搜索相关Tag", style: .default, handler: { _ in
                self.navigationController?.pushViewController(TagViewController(book: book), animated: true)
            }))
        }
        
        if let url = URL(string: SettingManager.shared.isLogin ? book.ExWebURLString : book.EWebURLString) {
            vc.addAction(UIAlertAction(title: "打开原网页", style: .default, handler: { _ in
                self.navigationController?.pushViewController(WebViewController(url: url, shareItem: (book.showTitle, ImageCache.default.retrieveImageInMemoryCache(forKey: book.thumb))), animated: true)
            }))
        }
        
        vc.addAction(UIAlertAction(title: "没事", style: .cancel, handler: nil))
        return vc
    }
}

// MARK: UITableViewDataSource
extension BookListViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        books.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: NSStringFromClass(BookListTableViewCell.self), for: indexPath)
        if let cell = cell as? BookListTableViewCell, indexPath.row < books.count {
            let book = books[indexPath.row]
            cell.updateWith(book: book)
            cell.longPressBlock = { [weak self] in
                guard let self = self else { return }
                self.present(self.makeAlertVC(with: book), animated: true, completion: nil)
            }
        }
        return cell
    }
}

// MARK: UITableViewDelegate
extension BookListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < books.count {
            navigationController?.pushViewController(GalleryViewController(book: books[indexPath.row]), animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let prefetchPoint = Int(Double(books.count) * 0.7)
        if indexPath.row >= prefetchPoint {
            loadMoreData()
        }
    }
}

