import SwiftUI

enum FlatTheme {
    // Warm architectural blueprint paper + industrial steel + safety amber
    static let paper = Color(red: 0.969, green: 0.961, blue: 0.941)        // #F7F5F0
    static let card = Color.white
    static let border = Color(red: 0.898, green: 0.882, blue: 0.847)       // #E5E1D8
    static let ink = Color(red: 0.082, green: 0.110, blue: 0.149)          // #151C26
    static let muted = Color(red: 0.392, green: 0.431, blue: 0.486)        // #646E7C
    static let slateCard = Color(red: 0.098, green: 0.133, blue: 0.184)    // #19222F
    static let accent = Color(red: 0.851, green: 0.420, blue: 0.086)       // #D96B16 Construction Amber
    static let accentSoft = Color(red: 0.992, green: 0.945, blue: 0.898)   // #FDF1E5
    static let paidGreen = Color(red: 0.082, green: 0.502, blue: 0.239)    // #15803D
    static let paidGreenSoft = Color(red: 0.914, green: 0.976, blue: 0.933)
    static let overdueRed = Color(red: 0.784, green: 0.118, blue: 0.118)   // #C81E1E
    static let overdueRedSoft = Color(red: 0.996, green: 0.922, blue: 0.922)
    static let estimateBlue = Color(red: 0.118, green: 0.376, blue: 0.722) // #1E60B8
    static let estimateBlueSoft = Color(red: 0.914, green: 0.949, blue: 0.996)
    static let gold = Color(red: 0.816, green: 0.580, blue: 0.094)

    static let cornerRadius: CGFloat = 16
}

struct FlatCardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(FlatTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: FlatTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FlatTheme.cornerRadius, style: .continuous)
                    .stroke(FlatTheme.border, lineWidth: 1)
            )
    }
}

extension View {
    func flatCard(padding: CGFloat = 16) -> some View {
        modifier(FlatCardModifier(padding: padding))
    }
}
