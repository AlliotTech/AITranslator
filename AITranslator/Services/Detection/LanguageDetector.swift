import Foundation
import NaturalLanguage

struct LanguageDetector {
    struct Result {
        let languageCode: String
        let confidence: Double
    }

    // MARK: - Bing Token Cache
    private static var cachedBingToken: (token: String, expiry: Date)?
    private static let bingTokenValiditySeconds: TimeInterval = 600  // 10 minutes
    
    // Network timeout for all detection requests
    private static let networkTimeoutSeconds: TimeInterval = 5.0
    
    // Centralized limit helper: 1000 for network engines, 200 for local
    static func limitedText(_ text: String, for engine: DetectionEngine) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = (engine == .local) ? 200 : 1000
        return String(trimmed.prefix(limit))
    }

    // Network session and proxy handling moved to HTTPClient

    static func detect(text: String, engine: DetectionEngine, proxy: HTTPClient.ProxySettings?) async -> Result {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .init(languageCode: "en", confidence: 0.5) }
        let limited = limitedText(trimmed, for: engine)

        if engine == .local {
            return localDetectLang(limited) ?? .init(languageCode: "en", confidence: 0.5)
        }

        // Try network engine first; on failure, degrade to local; always fallback to en
        let networkResult: Result? = await {
            switch engine {
            case .google: return await googleDetectLang(limited, proxy: proxy)
            case .baidu: return await baiduDetectLang(limited, proxy: proxy)
            case .bing: return await bingDetectLang(limited, proxy: proxy)
            case .local: return nil
            }
        }()

        if let ok = networkResult { return ok }
        if let local = localDetectLang(limitedText(trimmed, for: .local)) { return local }
        return .init(languageCode: "en", confidence: 0.5)
    }

    // MARK: - Local detection
    private static func localDetectLang(_ text: String) -> Result? {
        // Try NaturalLanguage framework first (macOS native, highly accurate)
        if let nlResult = detectWithNaturalLanguage(text) {
            return nlResult
        }
        
        // Fallback to regex-based detection if NL fails
        return detectWithRegex(text)
    }
    
    /// Use macOS NaturalLanguage framework for accurate language detection
    private static func detectWithNaturalLanguage(_ text: String) -> Result? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        guard let dominantLanguage = recognizer.dominantLanguage else {
            return nil
        }
        
        // Get confidence score (hypothesis with maximum probability)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[dominantLanguage] ?? 0.0
        
        // Only accept results with reasonable confidence
        guard confidence > 0.3 else {
            return nil
        }
        
        // Map NLLanguage to our language codes
        let langCode = mapNLLanguageCode(dominantLanguage.rawValue)
        return .init(languageCode: langCode, confidence: confidence)
    }
    
    /// Map NaturalLanguage codes to our standardized codes
    private static func mapNLLanguageCode(_ code: String) -> String {
        switch code {
        case "zh-Hans", "zh-CN", "zh":
            return "zh-CN"
        case "zh-Hant", "zh-TW", "zh-HK":
            return "zh-CN"  // Map to simplified as per current app support
        case "ja":
            return "ja"
        case "ko":
            return "ko"
        case "en":
            return "en"
        case "fr":
            return "fr"
        case "de":
            return "de"
        case "es":
            return "es"
        default:
            // For other languages, return as-is and let LanguageUtils handle standardization
            return code
        }
    }
    
    /// Fallback regex-based detection (original implementation)
    private static func detectWithRegex(_ text: String) -> Result? {
        let patterns: [String: String] = [
            "zh": "[\\u4e00-\\u9fa5]",
            "ko": "[\\uAC00-\\uD7A3]",
            "ja": "[\\u3040-\\u30ff]",
            "ru": "[\\u0400-\\u04FF]",
            "th": "[\\u0E01-\\u0E5B]",
            "vi": "[ÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚĂăẠ-ỹ]",
            "es": "[áéíóúüñÁÉÍÓÚÜÑ]",
            "fr": "[àâçéèêëîïôûùüÿœæÀÂÇÉÈÊËÎÏÔÛÙÜŸŒÆ]",
            "de": "[äöüßÄÖÜ]"
        ]

        var scores: [String: Int] = [:]
        for (lang, regex) in patterns {
            if let r = try? NSRegularExpression(pattern: regex, options: []) {
                let matches = r.numberOfMatches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
                scores[lang] = matches
            }
        }

        // Basic Latin letters heuristic for English
        let latinLetters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) && $0.value < 0x024F }.count
        let nonAsciiLetters = text.unicodeScalars.filter { $0.value > 0x024F && CharacterSet.letters.contains($0) }.count
        if latinLetters > max(5, nonAsciiLetters * 2) { scores["en", default: 0] += latinLetters / 5 }

        guard let (best, score) = scores.max(by: { $0.value < $1.value }), score > 0 else {
            // fallback simple heuristic
            if text.range(of: "[\\u4e00-\\u9fa5]", options: .regularExpression) != nil {
                return .init(languageCode: "zh-CN", confidence: 0.8)
            }
            return .init(languageCode: "en", confidence: 0.5)
        }

        let code: String
        if best == "zh" {
            code = "zh-CN"
        } else {
            code = best
        }
        // Normalize a rough confidence by clamping count
        let conf = min(0.99, Double(score) / Double(max(10, text.count)))
        return .init(languageCode: code, confidence: conf)
    }

    // MARK: - Google
    private static func googleDetectLang(_ text: String, proxy: HTTPClient.ProxySettings?) async -> Result? {
        guard var comps = URLComponents(string: "https://translate.google.com/translate_a/single") else { return nil }
        let dt = "at&dt=bd&dt=ex&dt=ld&dt=md&dt=qca&dt=rw&dt=rm&dt=ss&dt=t"
        comps.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: "auto"),
            URLQueryItem(name: "tl", value: "zh-CN"),
            URLQueryItem(name: "hl", value: "zh-CN"),
            URLQueryItem(name: "ie", value: "UTF-8"),
            URLQueryItem(name: "oe", value: "UTF-8"),
            URLQueryItem(name: "otf", value: "1"),
            URLQueryItem(name: "ssel", value: "0"),
            URLQueryItem(name: "tsel", value: "0"),
            URLQueryItem(name: "kc", value: "7"),
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "dt", value: dt)
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = networkTimeoutSeconds

        do {
            let (data, _) = try await HTTPClient.data(for: req, proxy: proxy)
            // Response is JavaScript-ish array, we can try to parse as JSON
            if let arr = try JSONSerialization.jsonObject(with: data) as? [Any], arr.count >= 3,
                let code = arr[2] as? String {
                let mapped = mapGoogleCode(code)
                return .init(languageCode: mapped, confidence: 0.9)
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func mapGoogleCode(_ code: String) -> String {
        switch code {
        case "zh-CN": return "zh-CN"
        case "zh-TW": return "zh-CN" // map Traditional to supported set
        default: return code
        }
    }

    // MARK: - Baidu
    private static func baiduDetectLang(_ text: String, proxy: HTTPClient.ProxySettings?) async -> Result? {
        guard let url = URL(string: "https://fanyi.baidu.com/langdetect") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = networkTimeoutSeconds
        let body = "query=" + (text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
        req.httpBody = body.data(using: .utf8)
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        do {
            let (data, _) = try await HTTPClient.data(for: req, proxy: proxy)
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let lan = obj["lan"] as? String {
                let mapped = mapBaiduCode(lan)
                return .init(languageCode: mapped, confidence: 0.9)
            }
        } catch {
            return nil
        }
        return nil
    }

    private static func mapBaiduCode(_ code: String) -> String {
        switch code.lowercased() {
        case "zh", "cht": return "zh-CN"
        case "en": return "en"
        case "jp": return "ja"
        case "kor": return "ko"
        case "fra": return "fr"
        case "de": return "de"
        case "spa": return "es"
        default: return code
        }
    }

    // MARK: - Bing
    private static func bingDetectLang(_ text: String, proxy: HTTPClient.ProxySettings?) async -> Result? {
        do {
            // Get or reuse cached token
            let token = try await getBingToken(proxy: proxy)
            
            guard let url = URL(string: "https://api-edge.cognitive.microsofttranslator.com/detect?api-version=3.0") else { return nil }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.timeoutInterval = networkTimeoutSeconds
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let json = [["Text": text]]
            let body = try JSONSerialization.data(withJSONObject: json)
            req.httpBody = body
            let (data, _) = try await HTTPClient.data(for: req, proxy: proxy)
            if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let first = arr.first,
                let lang = first["language"] as? String {
                let code = LanguageUtils.standardize(code: lang)
                return .init(languageCode: code, confidence: (first["score"] as? Double) ?? 1.0)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    /// Get Bing authentication token with caching
    private static func getBingToken(proxy: HTTPClient.ProxySettings?) async throws -> String {
        // Check if cached token is still valid
        if let cached = cachedBingToken, cached.expiry > Date() {
            return cached.token
        }
        
        // Fetch new token
        guard let tokenURL = URL(string: "https://edge.microsoft.com/translate/auth") else {
            throw NSError(domain: "LanguageDetector", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid token URL"])
        }
        
        var tokenReq = URLRequest(url: tokenURL)
        tokenReq.httpMethod = "GET"
        tokenReq.timeoutInterval = networkTimeoutSeconds
        
        let (tokenData, _) = try await HTTPClient.data(for: tokenReq, proxy: proxy)
        guard let token = String(data: tokenData, encoding: .utf8), !token.isEmpty else {
            throw NSError(domain: "LanguageDetector", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid token response"])
        }
        
        // Cache token with expiry time
        cachedBingToken = (token, Date().addingTimeInterval(bingTokenValiditySeconds))
        return token
    }
}
