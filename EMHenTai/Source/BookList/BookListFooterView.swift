//
//  BookListFooterView.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/19.
//

import UIKit

final class BookListFooterView: UIView {
    enum HintType: String {
        case empty = " "
        case loading = "加载中..."
        case noData = "无数据"
        case noMoreData = "没有更多了"
        case netError = "网络错误：请检查网络连接或VPN设置"
        case ipError = "IP错误：IP地址被禁，请尝试更换节点"
    }
    
    var hint = HintType.empty {
        didSet {
            label.text = hint.rawValue
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let label = {
        let label = UILabel()
        label.text = HintType.empty.rawValue
        label.font = .systemFont(ofSize: 14)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private func setupUI() {
        frame = CGRect(x: 0, y: 0, width: 0, height: ceil(label.font.lineHeight) + 20)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
