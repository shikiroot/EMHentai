//
//  SettingManager.swift
//  EMHenTai
//
//  Created by yuman on 2022/1/18.
//

import WebKit
import Kingfisher
import Combine

final class SettingManager {
    static let shared = SettingManager()
    static let LoginStateChangedNotification = NSNotification.Name(rawValue: "EMHenTai.SettingManager.LoginStateChangedNotification")
    
    private var cancelBag = Set<AnyCancellable>()
    
    lazy private(set) var isLogin = checkLogin() {
        didSet {
            if isLogin != oldValue {
                NotificationCenter.default.post(name: SettingManager.LoginStateChangedNotification, object: nil)
            }
        }
    }
    
    private init() {
        setupCombine()
    }
    
    private func setupCombine() {
        NotificationCenter.default
            .publisher(for: .NSHTTPCookieManagerCookiesChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isLogin = self.checkLogin()
            }
            .store(in: &cancelBag)
    }
    
    func loginWith(cookie: String) {
        guard case let coms = cookie.split(separator: "x"), coms.count == 2, coms[0].count > 32, coms[1].count > 0 else { return }
        let passHashs = createCookies(name: "ipb_pass_hash", value: "\(coms[0].prefix(32))")
        let memberIDs = createCookies(name: "ipb_member_id", value: "\(coms[0].suffix(coms[0].count - 32))")
        let igneouss = createCookies(name: "igneous", value: "\(coms[1])")
        
        for cookie in [passHashs, memberIDs, igneouss].flatMap({ $0 }).compactMap({ $0 }) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }
    
    func logout() {
        if let cookies = HTTPCookieStorage.shared.cookies {
            cookies.forEach { HTTPCookieStorage.shared.deleteCookie($0) }
        }
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            cookies.forEach { WKWebsiteDataStore.default().httpCookieStore.delete($0) }
        }
    }
    
    func calculateFileSize() async -> (historySize: Int, downloadSize: Int, otherSize: Int) {
        await withUnsafeContinuation { continuation in
            Task.detached {
                let otherSize = Int((try? KingfisherManager.shared.cache.diskStorage.totalSize()) ?? 0)
                guard let folders = try? FileManager.default.contentsOfDirectory(atPath: Book.downloadFolderPath), !folders.isEmpty else {
                    continuation.resume(returning: (0, 0, otherSize))
                    return
                }
                
                let size = folders.compactMap({ Int($0) }).reduce(into: (0, 0)) {
                    let folderSize = FileManager.default.folderSizeAt(path: Book.downloadFolderPath + "/\($1)")
                    if DBManager.shared.contains(gid: $1, of: .download) { $0.1 += folderSize }
                    else if DBManager.shared.contains(gid: $1, of: .history) { $0.0 += folderSize }
                }
                
                continuation.resume(returning: (size.0, size.1, otherSize))
            }
        }
    }
    
    func clearOtherData() async {
        await withUnsafeContinuation({ continuation in
            KingfisherManager.shared.cache.clearDiskCache {
                continuation.resume()
            }
        })
    }
    
    private func createCookies(name: String, value: String) -> [HTTPCookie?] {
        [HTTPCookie(properties: [.domain: ".exhentai.org", .name: name, .value: value, .path: "/", .expires: Date(timeInterval: 157784760, since: Date())]),
         HTTPCookie(properties: [.domain: ".e-hentai.org", .name: name, .value: value, .path: "/", .expires: Date(timeInterval: 157784760, since: Date())])]
    }
    
    private func checkLogin() -> Bool {
        guard let cookies = HTTPCookieStorage.shared.cookies, !cookies.isEmpty else { return false }
        func isValidID(_ id: String) -> Bool { !id.isEmpty && id.lowercased() != "mystery" && id.lowercased() != "null" }
        let currentDate = Date()
        var validFlags = (false, false, false)
        for cookie in cookies {
            guard let expiresDate = cookie.expiresDate, expiresDate > currentDate else { continue }
            if cookie.name == "ipb_member_id" { validFlags.0 = isValidID(cookie.value) }
            if cookie.name == "ipb_pass_hash" { validFlags.1 = isValidID(cookie.value) }
            if cookie.name == "igneous" { validFlags.2 = isValidID(cookie.value) }
            if validFlags == (true, true, true) { return true }
        }
        return false
    }
}
