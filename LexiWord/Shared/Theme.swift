import SwiftUI

// MARK: - Notion design palette
//
// All colours defined in sRGB to match the hex values exactly.
// Usage: Color.notionText, Color.notionSurface, etc.

extension Color {
    /// #FFFFFF — page/screen background
    static let notionBackground = Color(red: 1,           green: 1,           blue: 1)
    /// #191919 — primary text and high-emphasis UI
    static let notionText       = Color(red: 25  / 255,   green: 25  / 255,   blue: 25  / 255)
    /// #9B9A97 — secondary / placeholder text
    static let notionSecondary  = Color(red: 155 / 255,   green: 154 / 255,   blue: 151 / 255)
    /// #F1F0EE — card and surface backgrounds
    static let notionSurface    = Color(red: 241 / 255,   green: 240 / 255,   blue: 238 / 255)
    /// #E9E9E7 — 1 pt rule / border strokes; replaces shadows throughout
    static let notionBorder     = Color(red: 233 / 255,   green: 233 / 255,   blue: 231 / 255)
}

// MARK: - ShapeStyle shorthand
//
// Mirrors how SwiftUI exposes Color.red / .pink etc. via ShapeStyle extensions,
// allowing `.notionText` shorthand in .foregroundStyle(), .tint(), .fill(), etc.
// Without this, the compiler resolves the dot-syntax against ShapeStyle (not Color)
// inside @ViewBuilder closures and `some View`-returning functions and fails.

extension ShapeStyle where Self == Color {
    static var notionBackground: Color { .init(red: 1,           green: 1,           blue: 1) }
    static var notionText:       Color { .init(red: 25  / 255,   green: 25  / 255,   blue: 25  / 255) }
    static var notionSecondary:  Color { .init(red: 155 / 255,   green: 154 / 255,   blue: 151 / 255) }
    static var notionSurface:    Color { .init(red: 241 / 255,   green: 240 / 255,   blue: 238 / 255) }
    static var notionBorder:     Color { .init(red: 233 / 255,   green: 233 / 255,   blue: 231 / 255) }
}

// MARK: - Shared border modifier

extension View {
    /// 1 pt stroke in notionBorder, radius matches the caller's own corner radius.
    func notionBorderOverlay(cornerRadius: CGFloat = 8) -> some View {
        overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.notionBorder, lineWidth: 1))
    }
}
