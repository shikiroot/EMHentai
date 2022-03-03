//
//  DownloadManager.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/14.
//

import Foundation
import Alamofire

final class DownloadManager {
    enum DownloadState {
        case before
        case ing
        case suspend
        case finish
    }
    
    static let shared = DownloadManager()
    static let DownloadPageSuccessNotification = NSNotification.Name(rawValue: "EMHenTai.DownloadManager.DownloadPageSuccessNotification")
    static let DownloadStateChangedNotification = NSNotification.Name(rawValue: "EMHenTai.DownloadManager.DownloadStateChangedNotification")
    
    private init() {}
    private let taskMap = TaskMap()
    private let groupTotalImgNum = 40
    private let maxConcurrentDownloadCount = 8
    
    func download(book: Book) {
        Task {
            let state = await downloadState(of: book)
            if state == .ing || state == .finish {
                return
            }
            
            try? FileManager.default.createDirectory(at: URL(fileURLWithPath: book.folderPath), withIntermediateDirectories: true, attributes: nil)
            await taskMap.set(Task { await p_download(of: book) }, for: book.gid)
            NotificationCenter.default.post(name: DownloadManager.DownloadStateChangedNotification, object: book.gid, userInfo: nil)
        }
    }
    
    func suspend(book: Book) {
        Task {
            await taskMap.remove(book.gid)
            NotificationCenter.default.post(name: DownloadManager.DownloadStateChangedNotification, object: book.gid, userInfo: nil)
        }
    }
    
    func remove(book: Book) {
        Task {
            await taskMap.remove(book.gid)
            try? FileManager.default.removeItem(atPath: book.folderPath)
            NotificationCenter.default.post(name: DownloadManager.DownloadStateChangedNotification, object: book.gid, userInfo: nil)
        }
    }
    
    func downloadState(of book: Book) async -> DownloadState {
        if book.downloadedFileCount == book.fileCountNum {
            return .finish
        } else if await taskMap.isContain(book.gid) {
            return .ing
        } else {
            return book.downloadedFileCount == 0 ? .before : .suspend
        }
    }
    
    private func p_download(of book: Book) async {
        let urlStream = AsyncStream<String> { continuation in
            Task {
                await withTaskGroup(of: Void.self, body: { group in
                    let groupNum = book.fileCountNum / groupTotalImgNum + (book.fileCountNum % groupTotalImgNum == 0 ? 0 : 1)
                    for groupIndex in 0..<groupNum {
                        guard checkGroupNeedRequest(of: book, groupIndex: groupIndex) else { continue }
                        group.addTask {
                            let url = book.currentWebURLString + (groupIndex > 0 ? "?p=\(groupIndex)" : "")
                            guard let value = try? await AF.request(url).serializingString(automaticallyCancelling: true).value else { return }
                            let urls = value.allIndicesOf(string: SearchInfo.currentSource.rawValue + "s/").map { index -> String in
                                let start = value.index(value.startIndex, offsetBy: index)
                                var end = value.index(after: start)
                                while end < value.endIndex && value[end] != "\"" {
                                    end = value.index(after: end)
                                }
                                return "\(value[start..<end])"
                            }
                            urls.forEach { continuation.yield($0) }
                        }
                        await group.waitForAll()
                    }
                })
                continuation.finish()
            }
        }
        
        await withTaskGroup(of: Void.self, body: { group in
            var count = 0
            for await url in urlStream {
                let imgIndex = (url.split(separator: "-").last.flatMap({ Int("\($0)") }) ?? 1) - 1
                let imgKey = url.split(separator: "/").count > 1 ? url.split(separator: "/").reversed()[1] : ""
                guard !FileManager.default.fileExists(atPath: book.imagePath(at: imgIndex)) else { continue }
                guard !imgKey.isEmpty else { continue }
                
                count += 1
                if count > maxConcurrentDownloadCount {
                    await group.next()
                }
                
                group.addTask {
                    guard let value = try? await AF.request(url).serializingString(automaticallyCancelling: true).value else { return }
                    guard let showKey = value.range(of: "showkey=\"").map({ range -> Substring in
                        let start = range.upperBound
                        var end = value.index(after: start)
                        while end < value.endIndex && value[end] != "\"" {
                            end = value.index(after: end)
                        }
                        return value[start..<end]
                    }), !showKey.isEmpty else { return }
                    
                    guard let source = try? await AF.request(
                        SearchInfo.currentSource.rawValue + "api.php",
                        method: .post,
                        parameters: [
                            "method": "showpage",
                            "gid": book.gid,
                            "page": imgIndex + 1,
                            "imgkey": imgKey,
                            "showkey": showKey],
                        encoding: JSONEncoding.default
                    ).serializingDecodable(GroupModel.self, automaticallyCancelling: true).value.i3 else { return }
                    
                    guard let imgURL = source.range(of: "src=\"").map({ range -> String in
                        let start = range.upperBound
                        var end = source.index(after: start)
                        while end < source.endIndex && source[end] != "\"" {
                            end = source.index(after: end)
                        }
                        return "\(source[start..<end])"
                    }), !imgURL.isEmpty else { return }
                    
                    guard let p = try? await AF
                            .download(imgURL, to: { _, _ in (URL(fileURLWithPath: book.imagePath(at: imgIndex)), []) })
                            .serializingDownload(using: URLResponseSerializer(), automaticallyCancelling: true)
                            .value else { return }
                    
                    guard FileManager.default.fileExists(atPath: p.path) else { return }
                    NotificationCenter.default.post(name: DownloadManager.DownloadPageSuccessNotification, object: (book.gid, imgIndex), userInfo: nil)
                    if book.downloadedFileCount == book.fileCountNum {
                        await self.taskMap.remove(book.gid)
                        NotificationCenter.default.post(name: DownloadManager.DownloadStateChangedNotification, object: book.gid, userInfo: nil)
                    }
                }
            }
        })
    }
    
    private func checkGroupNeedRequest(of book: Book, groupIndex: Int) -> Bool {
        for index in 0..<groupTotalImgNum {
            let realIndex = groupIndex * groupTotalImgNum + index
            guard realIndex < book.fileCountNum else { break }
            if !FileManager.default.fileExists(atPath: book.imagePath(at: realIndex)) {
                return true
            }
        }
        return false
    }
}

private final actor TaskMap {
    var map = [Int: Task<Void, Never>]()
    
    func set(_ task: Task<Void, Never>, for gid: Int) {
        map[gid] = task
    }
    
    func remove(_ gid: Int) {
        map.removeValue(forKey: gid)?.cancel()
    }
    
    func isContain(_ gid: Int) -> Bool {
        map[gid] != nil
    }
}

private struct GroupModel: Codable {
    let i3: String
}
