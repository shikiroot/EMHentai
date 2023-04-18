//
//  DownloadManager.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/14.
//

import Alamofire
import Combine
import Foundation
import Kingfisher

final actor DownloadManager {
    enum State {
        case before
        case ing
        case suspend
        case finish
    }
    
    static let shared = DownloadManager()
    
    nonisolated let downloadStateChangedSubject = PassthroughSubject<(book: Book, state: State), Never>()
    nonisolated let downloadPageSuccessSubject = PassthroughSubject<(book: Book, index: Int), Never>()
    
    private init() {}
    private let groupTotalImgNum = 40
    private var taskMap = [Int: Task<Void, Never>]()
    
    nonisolated func download(_ book: Book) {
        Task { await p_download(book) }
    }
    
    private func p_download(_ book: Book) {
        guard case let state = downloadState(of: book), state != .ing && state != .finish else { return }
        
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: book.folderPath), withIntermediateDirectories: true)
        
        taskMap[book.gid] = Task {
            await pp_download(book)
            taskMap[book.gid] = nil
            if downloadState(of: book) == .finish {
                downloadStateChangedSubject.send((book, .finish))
            }
        }
        
        downloadStateChangedSubject.send((book, .ing))
    }
    
    nonisolated func suspend(_ book: Book) {
        Task { await p_suspend(book) }
    }
    
    private func p_suspend(_ book: Book) {
        taskMap[book.gid]?.cancel()
        taskMap[book.gid] = nil
        downloadStateChangedSubject.send((book, .suspend))
    }
    
    nonisolated func remove(_ book: Book) {
        Task { await p_remove(book) }
    }
    
    private func p_remove(_ book: Book) {
        taskMap[book.gid]?.cancel()
        taskMap[book.gid] = nil
        try? FileManager.default.removeItem(atPath: book.folderPath)
        downloadStateChangedSubject.send((book, .before))
    }
    
    func downloadState(of book: Book) -> State {
        if book.downloadedImgCount == book.contentImgCount + 1 {
            return .finish
        } else if taskMap[book.gid] != nil {
            return .ing
        } else {
            return book.downloadedImgCount == 0 ? .before : .suspend
        }
    }
    
    private nonisolated func pp_download(_ book: Book) async {
        if !FileManager.default.fileExists(atPath: book.coverImagePath) {
            let from = KingfisherManager.shared.cache.diskStorage.cacheFileURL(forKey: book.thumb)
            if FileManager.default.fileExists(atPath: from.path) {
                let to = URL(fileURLWithPath: book.coverImagePath)
                try? FileManager.default.copyItem(at: from, to: to)
            } else {
                _ = try? await AF
                    .download(book.thumb, interceptor: RetryPolicy(), to: { _, _ in (URL(fileURLWithPath: book.coverImagePath), []) })
                    .serializingDownload(using: URLResponseSerializer(), automaticallyCancelling: true)
                    .value
            }
        }
        
        let urlStream = AsyncStream<String> { continuation in
            Task {
                await withTaskGroup(of: Void.self, body: { group in
                    let groupNum = book.contentImgCount / groupTotalImgNum + (book.contentImgCount % groupTotalImgNum == 0 ? 0 : 1)
                    for groupIndex in 0..<groupNum {
                        guard checkGroupNeedRequest(of: book, groupIndex: groupIndex) else { continue }
                        group.addTask {
                            let url = book.currentWebURLString + (groupIndex > 0 ? "?p=\(groupIndex)" : "") + "/?nw=session"
                            guard let value = try? await AF.request(url, interceptor: RetryPolicy()).serializingString(automaticallyCancelling: true).value else { return }
                            let baseURL = SearchInfo.currentSource.rawValue + "s/"
                            value.allSubString(of: baseURL, endCharater: "\"").forEach { continuation.yield(baseURL + $0) }
                        }
                        await group.waitForAll()
                    }
                })
                continuation.finish()
            }
        }
        
        await withTaskGroup(of: Void.self, body: { group in
            for await url in urlStream {
                let imgIndex = (url.split(separator: "-").last.flatMap({ Int("\($0)") }) ?? 1) - 1
                let imgKey = url.split(separator: "/").count > 1 ? url.split(separator: "/").reversed()[1] : ""
                guard !FileManager.default.fileExists(atPath: book.imagePath(at: imgIndex)) else { continue }
                guard !imgKey.isEmpty else { continue }
                
                group.addTask { [weak self] in
                    guard let self else { return }
                    guard let value = try? await AF.request(url, interceptor: RetryPolicy()).serializingString(automaticallyCancelling: true).value else { return }
                    guard let showKey = value.allSubString(of: "showkey=\"", endCharater: "\"").first else { return }
                    
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
                    
                    guard let imgURL = source.allSubString(of: "src=\"", endCharater: "\"").first else { return }
                    
                    guard let p = try? await AF
                            .download(imgURL, interceptor: RetryPolicy(), to: { _, _ in (URL(fileURLWithPath: book.imagePath(at: imgIndex)), []) })
                            .serializingDownload(using: URLResponseSerializer(), automaticallyCancelling: true)
                            .value, FileManager.default.fileExists(atPath: p.path) else { return }
                    
                    downloadPageSuccessSubject.send((book, imgIndex))
                }
            }
        })
    }
    
    private nonisolated func checkGroupNeedRequest(of book: Book, groupIndex: Int) -> Bool {
        for index in 0 ..< groupTotalImgNum {
            guard case let realIndex = groupIndex * groupTotalImgNum + index, realIndex < book.contentImgCount else {
                break
            }
            if !FileManager.default.fileExists(atPath: book.imagePath(at: realIndex)) {
                return true
            }
        }
        return false
    }
}

private struct GroupModel: Codable {
    let i3: String
}
