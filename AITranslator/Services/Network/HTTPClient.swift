import Foundation
import CFNetwork
import Network

struct HTTPClient {
    struct ProxySettings {
        let type: ProxyType
        let host: String
        let port: Int
        let username: String?
        let password: String?
        let noProxyHosts: [String]
    }

    final class ProxyAuthDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
        private let username: String?
        private let password: String?

        init(username: String?, password: String?) {
            self.username = username
            self.password = password
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.isProxy(), let username, let password {
                let cred = URLCredential(user: username, password: password, persistence: .forSession)
                completionHandler(.useCredential, cred)
                return
            }
            completionHandler(.performDefaultHandling, nil)
        }
    }

    // MARK: - Session Cache Manager
    // 管理URLSession生命周期，避免内存泄漏
    private final class SessionCache {
        static let shared = SessionCache()

        private let lock = NSLock()
        private var cache: [String: URLSession] = [:]

        private init() {}

        func getSession(for key: String, builder: () -> URLSession) -> URLSession {
            // 先检查缓存（快速路径）
            lock.lock()
            if let existing = cache[key] {
                lock.unlock()
                return existing
            }
            lock.unlock()

            // 在锁外创建session，避免长时间持有锁
            let newSession = builder()

            // 再次获取锁，检查是否有其他线程已创建（双重检查）
            lock.lock()
            defer { lock.unlock() }

            if let existing = cache[key] {
                // 另一个线程已创建，丢弃新创建的session
                newSession.finishTasksAndInvalidate()
                return existing
            }

            cache[key] = newSession
            return newSession
        }

        // 清理所有缓存的session（用于代理配置变更时）
        // 返回清理前的session数量，用于日志
        @discardableResult
        func invalidateAll() -> Int {
            lock.lock()
            let sessions = Array(cache.values)
            let count = sessions.count
            cache.removeAll()
            lock.unlock()

            // 在锁外执行invalidate，避免死锁
            // finishTasksAndInvalidate会等待当前任务完成，不会中断正在进行的请求
            for session in sessions {
                session.finishTasksAndInvalidate()
            }

            return count
        }

        // 清理特定session
        func invalidate(for key: String) {
            lock.lock()
            let session = cache.removeValue(forKey: key)
            lock.unlock()

            session?.finishTasksAndInvalidate()
        }
    }

    // MARK: - Public convenience APIs

    /// 发送HTTP请求并返回数据
    /// - 自动复用相同代理配置的URLSession
    /// - 线程安全，可并发调用
    static func data(for request: URLRequest, proxy: ProxySettings?) async throws -> (Data, URLResponse) {
        let session = getOrCreateSession(proxy: proxy, targetHost: request.url?.host)
        return try await session.data(for: request)
    }

    /// 发送HTTP请求并返回流式数据
    /// - 自动复用相同代理配置的URLSession
    /// - 线程安全，可并发调用
    static func bytes(for request: URLRequest, proxy: ProxySettings?) async throws -> (URLSession.AsyncBytes, URLResponse) {
        let session = getOrCreateSession(proxy: proxy, targetHost: request.url?.host)
        return try await session.bytes(for: request)
    }

    /// 清理所有缓存的URLSession（当代理设置改变时调用）
    /// - 注意：使用finishTasksAndInvalidate，会等待当前任务完成
    /// - 不会中断正在进行的请求，但会阻止新任务使用旧session
    /// - 线程安全
    static func invalidateAllSessions() {
        SessionCache.shared.invalidateAll()
    }

    // MARK: - Session management
    // 根据代理配置获取或创建session，实现复用以避免内存泄漏
    private static func getOrCreateSession(proxy: ProxySettings?, targetHost: String?) -> URLSession {
        // 无代理或需要bypass时，使用共享session
        guard let proxy else { return URLSession.shared }

        if let h = targetHost?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           shouldBypassProxy(for: h, noProxyHosts: proxy.noProxyHosts) {
            return URLSession.shared
        }

        // 生成缓存key，包含所有代理配置参数
        let cacheKey = generateCacheKey(for: proxy)

        return SessionCache.shared.getSession(for: cacheKey) {
            buildSession(proxy: proxy)
        }
    }

    // 生成session缓存key
    private static func generateCacheKey(for proxy: ProxySettings) -> String {
        let username = proxy.username ?? ""
        let password = proxy.password ?? ""
        let bypass = proxy.noProxyHosts.joined(separator: ",")
        return "\(proxy.type.rawValue):\(proxy.host):\(proxy.port):\(username):\(password):\(bypass)"
    }

    // 构建新的URLSession实例
    private static func buildSession(proxy: ProxySettings) -> URLSession {
        let config = URLSessionConfiguration.default
        var proxyDict: [AnyHashable: Any] = [:]

        switch proxy.type {
        case .none:
            break
        case .http:
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = proxy.port
            proxyDict[kCFNetworkProxiesHTTPSEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPSProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesHTTPSPort as String] = proxy.port
        case .socks5:
            proxyDict[kCFNetworkProxiesSOCKSEnable as String] = 1
            proxyDict[kCFNetworkProxiesSOCKSProxy as String] = proxy.host
            proxyDict[kCFNetworkProxiesSOCKSPort as String] = proxy.port
        }

        let exceptions = proxy.noProxyHosts.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !exceptions.isEmpty {
            proxyDict[kCFNetworkProxiesExceptionsList as String] = exceptions
        }

        if !proxyDict.isEmpty {
            config.connectionProxyDictionary = proxyDict
        }

        let delegate: ProxyAuthDelegate? = (proxy.type == .http) ? ProxyAuthDelegate(username: proxy.username, password: proxy.password) : nil
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    private static func shouldBypassProxy(for host: String, noProxyHosts: [String]) -> Bool {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !h.isEmpty else { return false }
        for raw in noProxyHosts {
            let token = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if token.isEmpty { continue }
            if token == h { return true }
            if token.hasPrefix("*.") {
                let suffix = String(token.dropFirst(1))
                if h.hasSuffix(suffix) { return true }
            } else if token.first == "." {
                if h.hasSuffix(token) { return true }
            }
        }
        return false
    }

    // Simple TCP connectivity test to the proxy server itself (host:port)
    static func testProxy(_ proxy: ProxySettings, timeout: TimeInterval = 3.0) async -> Bool {
        let trimmedHost = proxy.host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return false }
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: proxy.port)), port.rawValue > 0 else { return false }

        let connection = NWConnection(host: NWEndpoint.Host(trimmedHost), port: port, using: .tcp)
        return await withCheckedContinuation { continuation in
            final class FinishBox: @unchecked Sendable {
                let lock = NSLock()
                var finished: Bool = false
                var timeoutWorkItem: DispatchWorkItem?
            }
            let box = FinishBox()
            let complete: @Sendable (Bool) -> Void = { ok in
                box.lock.lock()
                defer { box.lock.unlock() }
                if box.finished { return }
                box.finished = true
                // 取消超时任务，避免在成功后仍然执行
                box.timeoutWorkItem?.cancel()
                continuation.resume(returning: ok)
                connection.cancel()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    complete(true)
                case .failed(_):
                    complete(false)
                default:
                    break
                }
            }
            connection.start(queue: .global())

            let workItem = DispatchWorkItem {
                complete(false)
            }
            box.lock.lock()
            box.timeoutWorkItem = workItem
            box.lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: workItem)
        }
    }
}
