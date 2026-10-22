import UIKit

enum GrainHaptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)

    static func prepare() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }

    static func selection(enabled: Bool) {
        guard enabled else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    static func lightImpact(enabled: Bool) {
        guard enabled else { return }
        lightGenerator.impactOccurred()
        lightGenerator.prepare()
    }

    static func mediumImpact(enabled: Bool) {
        guard enabled else { return }
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }
}
