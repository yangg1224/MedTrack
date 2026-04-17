import SwiftUI

enum A11y {
    /// Minimum row height for all interactive list rows.
    static let minRowHeight: CGFloat = 60

    /// Minimum body font — never go below this for readable text.
    static let bodyFont: Font = .title3

    /// Slightly larger for primary labels.
    static let labelFont: Font = .title2

    /// Large, attention-grabbing font for primary actions.
    static let actionFont: Font = .title3.weight(.semibold)
}
