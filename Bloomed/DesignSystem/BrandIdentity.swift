import SwiftUI

/// Outlined artwork keeps the identity identical in-app and in shared images.
/// Other interface text continues to use the native, accessible system font.
struct BBrandLockup: View {
    var height: CGFloat = 28
    @ScaledMetric(relativeTo: .title3) private var typeScale = 1.0
    private let aspectRatio = 4.72584675811443

    var body: some View {
        let scaledHeight = min(height * typeScale, 40)
        Image("BloomedLockup")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .frame(width: scaledHeight * aspectRatio, height: scaledHeight)
            .accessibilityLabel("Bloomed")
    }
}

enum BBrandIllustration: String {
    case walking = "WalkingRoute"
    case progress = "GrowingLoops"
    case support = "SupportPair"
}

struct BBrandArtwork: View {
    let kind: BBrandIllustration

    var body: some View {
        Image(kind.rawValue)
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(BTheme.accent)
            .accessibilityHidden(true)
    }
}
