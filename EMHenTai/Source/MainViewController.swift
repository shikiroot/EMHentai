//
//  MainViewController.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/14.
//

import Foundation
import UIKit

class MainViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        viewControllers = [
            {
                let vc = UINavigationController(rootViewController: BookListViewController(type: .Home))
                vc.tabBarItem.title = "主页"
                return vc
            }(),
            {
                let vc = UINavigationController(rootViewController: BookListViewController(type: .History))
                vc.tabBarItem.title = "历史"
                return vc
            }(),
            {
                let vc = UINavigationController(rootViewController: BookListViewController(type: .Download))
                vc.tabBarItem.title = "下载"
                return vc
            }(),
            {
                let vc = UINavigationController(rootViewController: SettingViewController())
                vc.tabBarItem.title = "设置"
                return vc
            }(),
        ]
    }
}
