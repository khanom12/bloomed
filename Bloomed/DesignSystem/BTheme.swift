import SwiftUI
import UIKit

enum BTheme {
    static let background = adaptive("F6F8F5", "111B16")
    static let surface = adaptive("FFFFFF", "19271F")
    static let ink = adaptive("172B24", "F0F5EF")
    static let secondary = adaptive("52645A", "B5C5B8")
    static let accent = adaptive("23634B", "A0D5AF")
    static let accentSoft = adaptive("E8F1EB", "263D2E")
    static let onAccent = adaptive("FFFFFF", "13271B")
    static let warning = adaptive("805600", "EAC571")
    static let warningSoft = adaptive("FFF3D6", "3B3019")
    static let destructive = adaptive("A32B35", "FFB4BA")
    static let divider = adaptive("D7E1D9", "3C5142")

    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            let value = UInt64(traits.userInterfaceStyle == .dark ? dark : light, radix: 16) ?? 0
            return UIColor(red: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

enum Format {
    static func money(_ cents: Int) -> String {
        let number = NSDecimalNumber(value: cents).dividing(by: 100)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "CAD \(number.stringValue)"
    }

    static func steps(_ value: Int) -> String { value.formatted() }

    static func date(_ key: String, timezoneID: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timezoneID)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    static func day(_ key: String, timezoneID: String) -> String {
        guard let date = date(key, timezoneID: timezoneID) else { return key }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezoneID)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    static func weekday(_ key: String, timezoneID: String) -> String {
        guard let date = date(key, timezoneID: timezoneID) else { return key }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezoneID)
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date)
    }

    static func week(_ plan: WeeklyPlan) -> String {
        let start = day(plan.startDateKey, timezoneID: plan.timezoneID)
        let end = day(plan.dateKeys.last ?? plan.startDateKey, timezoneID: plan.timezoneID)
        return "\(start) – \(end)"
    }
}

func money(_ cents: Int) -> String { Format.money(cents) }
