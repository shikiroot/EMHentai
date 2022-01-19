//
//  BookFooterView.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/19.
//

import Foundation
import UIKit

enum BookFooterHint: String {
    case none = " "
    case noData = "没有数据"
    case noMoreData = "没有更多数据"
    case netError = "网络错误：请确认网络连接或VPN设置"
}

class BookFooterView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    private let label: UILabel = {
        let label = UILabel()
        label.text = BookFooterHint.none.rawValue
        label.font = UIFont.systemFont(ofSize: 14)
        label.sizeToFit()
        return label
    }()
    
    private func setupUI() {
        frame = CGRect(x: 0, y: 0, width: 0, height: label.bounds.size.height + 20)
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }
    
    func update(hint: BookFooterHint) {
        self.label.text = hint.rawValue
    }
}
