//
//  Book.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/14.
//

import Foundation

struct Gmetadata: Codable {
    let gmetadata: [Book]
}

struct Book: Codable {
    let gid: Int
    let title: String
    let title_jpn: String
    let category: String
    let thumb: String
    let uploader: String
    let filecount: String
    let filesize: Int
    let tags: [String]
    let token: String
    let rating: String
    let archiver_key: String
    let posted: String
    let expunged: Bool
    let torrentcount: String
    let torrents: [torrent]
}

struct torrent: Codable {
    let hash: String
    let added: String
    let name: String
    let tsize: String
    let fsize: String
}

extension Book {
    func imageString(at pageIndex: Int) -> String {
        var url = "\(SearchInfo().source)g/\(gid)/\(token)"
        if pageIndex > 0 { url += "?p=\(pageIndex)" }
        url += "&inline_set=ts_m"
        return url
    }
}
