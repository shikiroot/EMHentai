//
//  Book+Tools.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/19.
//

import Foundation

extension Book {
    var showTitle: String { title_jpn.isEmpty ? title : title_jpn }
}

extension Book {
    static var downloadFolderPath: String {
        if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
            return path + "/EMDownload"
        } else {
            return NSHomeDirectory() + "/Documents" + "/EMDownload"
        }
    }
    
    var folderPath: String {
        Book.downloadFolderPath + "/\(gid)"
    }
    
    func imagePath(at index: Int) -> String {
        folderPath + "/\(gid)-\(index).jpg"
    }
    
    var fileCountNum: Int {
        Int(filecount) ?? 0
    }
    
    var downloadedFileCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: folderPath))?.count ?? 0
    }
}
