import Foundation

enum RegionalPaywallStyle: String, Equatable {
    case angloROI
    case euPrivacyLifetime
    case eastAsiaDetail

    static func forRegion(_ code: String?) -> RegionalPaywallStyle {
        let region = (code ?? "").uppercased()
        let euRegions: Set<String> = [
            "DE", "CH", "AT", "GB", "FR", "NL", "BE", "LU", "IE",
            "SE", "NO", "DK", "FI", "ES", "IT", "PT", "PL", "CZ",
        ]
        let eastAsiaRegions: Set<String> = ["JP", "KR", "TW", "HK", "MO", "SG"]
        if euRegions.contains(region) { return .euPrivacyLifetime }
        if eastAsiaRegions.contains(region) { return .eastAsiaDetail }
        return .angloROI
    }
}

enum L10n {
    static var forcedLanguage: String? = {
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-ui_lang"), idx + 1 < args.count {
            return args[idx + 1]
        }
        return nil
    }()

    static var preferredTag: String {
        (forcedLanguage ?? Locale.preferredLanguages.first ?? "en").lowercased()
    }

    static var isTraditionalChinese: Bool {
        let tag = preferredTag
        return tag.hasPrefix("zh-hant")
            || tag.hasPrefix("zh-hk")
            || tag.hasPrefix("zh-tw")
            || tag.hasPrefix("zh-mo")
    }

    static var isChinese: Bool {
        preferredTag.hasPrefix("zh")
    }

    static var paywallStyle: RegionalPaywallStyle {
        RegionalPaywallStyle.forRegion(Locale.current.region?.identifier)
    }

    static func t(_ en: String, _ zhHans: String) -> String {
        isChinese ? zhHans : en
    }

    static func t(_ en: String, _ zhHans: String, _ zhHant: String) -> String {
        if isTraditionalChinese { return zhHant }
        if isChinese { return zhHans }
        return en
    }
}
