import SwiftUI

struct AuditHistoryView: View {
    @Environment(AppStore.self) private var store
    let planID: UUID
    var body: some View {
        List {
            Section("Assessment revisions") {
                ForEach(store.state.assessments.filter { $0.planID == planID }.reversed()) { revision in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(revision.reviewedAt == nil ? "Provisional revision" : "Reviewed revision").font(.headline)
                        Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                        BMoneyRow(title: "Personal return", cents: revision.result.personalReturnCents)
                        BMoneyRow(title: "Charity allocation", cents: revision.result.charityAllocationCents)
                        BMoneyRow(title: "Supporter reward", cents: revision.result.supporterRewardCents)
                    }.padding(.vertical, 8)
                }
            }
            Section("Recorded actions") {
                ForEach(store.state.auditEvents.filter { $0.planID == planID }.reversed()) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.action.rawValue.replacingOccurrences(of: "_", with: " ").capitalized).font(.headline)
                        Text(event.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(BTheme.secondary)
                        if !event.reason.isEmpty { Text(event.reason).font(.subheadline) }
                    }.padding(.vertical, 4)
                }
            }
        }.navigationTitle("Record history").navigationBarTitleDisplayMode(.inline)
    }
}
