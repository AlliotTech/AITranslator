import Foundation

extension Preferences {
    /// 构建代理配置（统一入口，避免重复代码）
    var proxySettings: HTTPClient.ProxySettings? {
        let type = proxyType
        let host = proxyHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = proxyPort

        if type == .none || host.isEmpty || port <= 0 { return nil }

        let username = proxyUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = proxyPassword
        let bypass = noProxyTargets
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        return HTTPClient.ProxySettings(
            type: type,
            host: host,
            port: port,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            noProxyHosts: bypass
        )
    }

    /// 当前偏好的 DeepL 服务配置
    var deepLConfiguration: DeepLServiceConfiguration {
        DeepLServiceConfiguration(
            baseURL: resolvedDeepLBaseURL,
            apiKey: deepLAPIKey,
            apiFamily: resolvedDeepLAPIFamily,
            supportsWrite: deepLSupportsWrite
        )
    }
}
