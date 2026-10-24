import SwiftUI

struct BCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(BTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}

struct BPrimaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    var body: some View {
        Button(action: action) {
            Text(title).font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? BTheme.onAccent : BTheme.secondary)
        .background(isEnabled ? BTheme.accent : BTheme.accentSoft, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct BEmptyState: View {
    let title: String
    let message: String
    var symbol = "leaf"
    var illustration: BBrandIllustration? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        BCard {
            if let illustration {
                BBrandArtwork(kind: illustration)
                    .frame(width: 120, height: 72, alignment: .leading)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol).font(.system(size: 32, weight: .light))
                    .foregroundStyle(BTheme.accent).accessibilityHidden(true)
            }
            Text(title).font(.title2.weight(.semibold)).foregroundStyle(BTheme.ink)
            Text(message).font(.body).foregroundStyle(BTheme.secondary)
            if let actionTitle, let action { BPrimaryButton(title: actionTitle, action: action) }
        }
    }
}

struct BMoneyRow: View {
    let title: String
    let cents: Int
    var emphasized = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) { label; value }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        label.fixedSize(horizontal: true, vertical: true)
                        Spacer(minLength: 8)
                        value.fixedSize(horizontal: true, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 6) { label; value }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
    private var label: some View { Text(title).foregroundStyle(BTheme.secondary) }
    private var value: some View {
        Text(Format.money(cents)).font(emphasized ? .title2.weight(.semibold) : .body.weight(.semibold))
            .monospacedDigit().foregroundStyle(BTheme.ink).fixedSize(horizontal: false, vertical: true)
    }
}

struct BSectionTitle: View {
    let title: String
    var body: some View {
        Text(title).font(.headline).foregroundStyle(BTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BStatusBadge: View {
    let title: String
    var warning = false
    var body: some View {
        Text(title).font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6)
            .foregroundStyle(warning ? BTheme.warning : BTheme.accent)
            .background(warning ? BTheme.warningSoft : BTheme.accentSoft, in: Capsule())
    }
}

struct BScreenHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if eyebrow == "Bloomed" {
                BBrandLockup().foregroundStyle(BTheme.accent)
            } else {
                Text(eyebrow.uppercased()).font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(BTheme.secondary)
            }
            Text(title).font(.largeTitle.weight(.bold)).tracking(-0.7).foregroundStyle(BTheme.ink)
            Text(subtitle).font(.body).foregroundStyle(BTheme.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BNotice: View {
    let message: String
    var warning = false
    var body: some View {
        Label(message, systemImage: warning ? "exclamationmark.circle" : "info.circle")
            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(warning ? BTheme.warning : BTheme.secondary)
            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(warning ? BTheme.warningSoft : BTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct BStepProgress: View {
    let steps: Int
    let base: Int
    let stretch: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(BTheme.accentSoft)
                    Capsule().fill(BTheme.accent)
                        .frame(width: proxy.size.width * min(CGFloat(steps) / CGFloat(stretch ?? base), 1))
                    if let stretch {
                        Rectangle().fill(BTheme.secondary)
                            .frame(width: 2, height: 18)
                            .offset(x: max(0, proxy.size.width * CGFloat(base) / CGFloat(stretch) - 1))
                    }
                }
            }.frame(height: 10).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack { target("Base", value: base); Spacer(); if let stretch { target("Stretch", value: stretch) } }
                VStack(alignment: .leading, spacing: 6) { target("Base", value: base); if let stretch { target("Stretch", value: stretch) } }
            }
            if steps < (stretch ?? base) {
                Text("\(max(0, (steps < base ? base : (stretch ?? base)) - steps).formatted()) steps to \(steps < base ? (stretch == nil ? "your daily goal" : "your base goal") : "your stretch goal")")
                    .font(.caption).foregroundStyle(BTheme.secondary)
            } else {
                Text("Daily goal reached. Extra steps stay in your activity record; your daily return is capped.")
                    .font(.caption).foregroundStyle(BTheme.secondary)
            }
        }
    }
    private func target(_ title: String, value: Int) -> some View {
        Label("\(stretch == nil ? "Daily goal" : title): \(value.formatted())", systemImage: steps >= value ? "checkmark.circle.fill" : "circle")
            .font(.subheadline).foregroundStyle(steps >= value ? BTheme.accent : BTheme.secondary)
    }
}

struct BErrorText: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.circle").font(.subheadline)
            .foregroundStyle(BTheme.destructive).fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

extension View {
    func bloomedScreen() -> some View {
        self.frame(maxWidth: 640).padding(20).frame(maxWidth: .infinity)
            .background(BTheme.background.ignoresSafeArea())
    }
}
