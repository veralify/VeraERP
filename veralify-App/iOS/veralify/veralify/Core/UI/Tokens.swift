// GENERATED from tokens.json — edit tokens.json
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum VeraTokens {
    public enum Colors {
        public static let bg = Color(light: "F8FAFC", dark: "050609")
        public static let bgSubtle = Color(light: "FFFFFF", dark: "0B1018")
        public static let surface = Color(light: "FFFFFF", dark: "101720")
        public static let surfaceMuted = Color(light: "E8ECF1", dark: "141A23")
        public static let elevated = Color(light: "FFFFFF", dark: "1B2330")
        public static let overlay = Color(light: "05060966", dark: "050609CC")
        public static let fg = Color(light: "0B1018", dark: "F8FAFC")
        public static let fgMuted = Color(light: "3B4656", dark: "B7C2D2")
        public static let fgSubtle = Color(light: "586475", dark: "8390A3")
        public static let fgInverse = Color(light: "FFFFFF", dark: "050609")
        public static let primary = Color(light: "1B63C8", dark: "4D95F7")
        public static let primaryStrong = Color(light: "164EA0", dark: "7DB4FF")
        public static let onPrimary = Color(light: "FFFFFF", dark: "050609")
        public static let secondary = Color(light: "B95310", dark: "DE6C15")
        public static let onSecondary = Color(light: "FFFFFF", dark: "050609")
        public static let accent = Color(light: "7048D7", dark: "8B5CF6")
        public static let onAccent = Color(light: "FFFFFF", dark: "FFFFFF")
        public static let success = Color(light: "11823B", dark: "30C46B")
        public static let warning = Color(light: "875D00", dark: "FFD13D")
        public static let danger = Color(light: "BE123C", dark: "F84C5F")
        public static let info = Color(light: "087F99", dark: "5AD8F6")
        public static let border = Color(light: "D5DEE8", dark: "2A3545")
        public static let borderStrong = Color(light: "7C899B", dark: "586475")
        public static let focus = Color(light: "1B63C8", dark: "7DB4FF")
        public static let glass = Color(light: "FFFFFFCC", dark: "101720B8")
        public static let glassBorder = Color(light: "05060914", dark: "FFFFFF1F")
        public static let coachAccent = Color(light: "B95310", dark: "DE6C15")

        public enum Nutrition {
            public static let calories = Color(light: "875D00", dark: "FFD13D")
            public static let protein = Color(light: "087F99", dark: "5AD8F6")
            public static let carbs = Color(light: "11823B", dark: "30C46B")
            public static let fat = Color(light: "B95310", dark: "DE6C15")
            public static let water = Color(light: "1B63C8", dark: "4D95F7")
        }

        public enum Progress {
            public static let onTrack = Color(light: "11823B", dark: "30C46B")
            public static let behind = Color(light: "875D00", dark: "FFD13D")
            public static let exceeded = Color(light: "BE123C", dark: "F84C5F")
        }

        public enum Live {
            public static let liveRed = Color(light: "BE123C", dark: "F84C5F")
            public static let speakingGlow = Color(light: "1B63C8", dark: "7DB4FF")
        }

        public enum Ramp {
            public enum Slate {
                    public static let _0 = Color(hex: "FFFFFF")
                    public static let _50 = Color(hex: "F8FAFC")
                    public static let _100 = Color(hex: "E8ECF1")
                    public static let _200 = Color(hex: "D5DEE8")
                    public static let _300 = Color(hex: "AAB7C7")
                    public static let _400 = Color(hex: "7C899B")
                    public static let _500 = Color(hex: "586475")
                    public static let _600 = Color(hex: "3B4656")
                    public static let _700 = Color(hex: "232B37")
                    public static let _800 = Color(hex: "141A23")
                    public static let _900 = Color(hex: "0B1018")
                    public static let _950 = Color(hex: "050609")
            }
            public enum Blue {
                    public static let _50 = Color(hex: "EAF3FF")
                    public static let _100 = Color(hex: "D6E8FF")
                    public static let _200 = Color(hex: "ADD1FF")
                    public static let _300 = Color(hex: "7DB4FF")
                    public static let _400 = Color(hex: "4D95F7")
                    public static let _500 = Color(hex: "2F7DEB")
                    public static let _600 = Color(hex: "1B63C8")
                    public static let _700 = Color(hex: "164EA0")
                    public static let _800 = Color(hex: "123B78")
                    public static let _900 = Color(hex: "0B244A")
            }
            public enum Ember {
                    public static let _50 = Color(hex: "FFF3EA")
                    public static let _100 = Color(hex: "FFE0C7")
                    public static let _200 = Color(hex: "FFC18F")
                    public static let _300 = Color(hex: "FF9C52")
                    public static let _400 = Color(hex: "F47B22")
                    public static let _500 = Color(hex: "DE6C15")
                    public static let _600 = Color(hex: "B95310")
                    public static let _700 = Color(hex: "8F3F0E")
                    public static let _800 = Color(hex: "642B0A")
                    public static let _900 = Color(hex: "3F1A06")
            }
            public enum Green {
                    public static let _50 = Color(hex: "EAFBF1")
                    public static let _100 = Color(hex: "CFF5DD")
                    public static let _200 = Color(hex: "9BEABB")
                    public static let _300 = Color(hex: "5ED890")
                    public static let _400 = Color(hex: "30C46B")
                    public static let _500 = Color(hex: "16A34A")
                    public static let _600 = Color(hex: "11823B")
                    public static let _700 = Color(hex: "0E642F")
                    public static let _800 = Color(hex: "0A4622")
                    public static let _900 = Color(hex: "062D16")
            }
            public enum Yellow {
                    public static let _50 = Color(hex: "FFF8E1")
                    public static let _100 = Color(hex: "FFEFB3")
                    public static let _200 = Color(hex: "FFE077")
                    public static let _300 = Color(hex: "FFD13D")
                    public static let _400 = Color(hex: "F6BD16")
                    public static let _500 = Color(hex: "DFA000")
                    public static let _600 = Color(hex: "B77E00")
                    public static let _700 = Color(hex: "875D00")
                    public static let _800 = Color(hex: "5B3E00")
                    public static let _900 = Color(hex: "382500")
            }
            public enum Red {
                    public static let _50 = Color(hex: "FFF0F1")
                    public static let _100 = Color(hex: "FFD9DD")
                    public static let _200 = Color(hex: "FFADB6")
                    public static let _300 = Color(hex: "FF7A88")
                    public static let _400 = Color(hex: "F84C5F")
                    public static let _500 = Color(hex: "E11D48")
                    public static let _600 = Color(hex: "BE123C")
                    public static let _700 = Color(hex: "98112F")
                    public static let _800 = Color(hex: "671022")
                    public static let _900 = Color(hex: "3F0812")
            }
            public enum Violet {
                    public static let _50 = Color(hex: "F5F0FF")
                    public static let _100 = Color(hex: "EADBFF")
                    public static let _200 = Color(hex: "D7B8FF")
                    public static let _300 = Color(hex: "BF8BFF")
                    public static let _400 = Color(hex: "A855F7")
                    public static let _500 = Color(hex: "8B5CF6")
                    public static let _600 = Color(hex: "7048D7")
                    public static let _700 = Color(hex: "5637A8")
                    public static let _800 = Color(hex: "38246E")
                    public static let _900 = Color(hex: "221544")
            }
            public enum Cyan {
                    public static let _50 = Color(hex: "E8FAFF")
                    public static let _100 = Color(hex: "C9F3FF")
                    public static let _200 = Color(hex: "93E7FF")
                    public static let _300 = Color(hex: "5AD8F6")
                    public static let _400 = Color(hex: "22C7E8")
                    public static let _500 = Color(hex: "06A9C9")
                    public static let _600 = Color(hex: "087F99")
                    public static let _700 = Color(hex: "0B6075")
                    public static let _800 = Color(hex: "0A4050")
                    public static let _900 = Color(hex: "052933")
            }
        }
    }

    public enum Typography {
        public struct FontToken { public let size: CGFloat; public let lineHeight: CGFloat; public let weight: Font.Weight; public let tracking: CGFloat }
        public static let display = FontToken(size: 56, lineHeight: 60, weight: .heavy, tracking: -1.7)
        public static let h1 = FontToken(size: 40, lineHeight: 46, weight: .bold, tracking: -1.1)
        public static let h2 = FontToken(size: 32, lineHeight: 38, weight: .bold, tracking: -0.8)
        public static let h3 = FontToken(size: 24, lineHeight: 30, weight: .bold, tracking: -0.4)
        public static let body = FontToken(size: 16, lineHeight: 24, weight: .regular, tracking: 0)
        public static let bodyStrong = FontToken(size: 16, lineHeight: 24, weight: .semibold, tracking: 0)
        public static let caption = FontToken(size: 13, lineHeight: 18, weight: .medium, tracking: 0.1)
        public static let monoNumeric = FontToken(size: 22, lineHeight: 28, weight: .bold, tracking: -0.3)
        public static let sans = "Inter"
        public static let mono = "SF Mono"
    }

    public enum Spacing {
        public static let _0: CGFloat = 0
        public static let _1: CGFloat = 4
        public static let _2: CGFloat = 8
        public static let _3: CGFloat = 12
        public static let _4: CGFloat = 16
        public static let _5: CGFloat = 20
        public static let _6: CGFloat = 24
        public static let _8: CGFloat = 32
        public static let _10: CGFloat = 40
        public static let _12: CGFloat = 48
        public static let _16: CGFloat = 64
        public static let _20: CGFloat = 80
        public static let _24: CGFloat = 96
    }

    public enum Radii {
        public static let xs: CGFloat = 6
        public static let sm: CGFloat = 10
        public static let md: CGFloat = 14
        public static let lg: CGFloat = 20
        public static let xl: CGFloat = 28
        public static let _2xl: CGFloat = 36
        public static let pill: CGFloat = 999
    }

    public enum Borders {
        public static let hairline: CGFloat = 0.5
        public static let `default`: CGFloat = 1
        public static let strong: CGFloat = 2
        public static let focus: CGFloat = 3
    }

    public enum Motion {
        public enum Duration {
            public static let instant = Double(80) / 1000.0
            public static let fast = Double(150) / 1000.0
            public static let base = Double(220) / 1000.0
            public static let slow = Double(360) / 1000.0
            public static let hero = Double(520) / 1000.0
        }
    }

    public enum ZIndex {
        public static let base = 0
        public static let raised = 10
        public static let sticky = 100
        public static let nav = 200
        public static let overlay = 400
        public static let modal = 500
        public static let toast = 600
        public static let coachmark = 700
    }

    public enum SafeArea {
        public static let minimumHitTarget: CGFloat = 44
        public static let bottomNavClearance: CGFloat = 96
        public static let edgePadding: CGFloat = 16
    }
}

public extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        if cleaned.count > 6 {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        } else {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    init(light: String, dark: String) {
#if canImport(UIKit)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
#else
        self.init(hex: light)
#endif
    }
}
