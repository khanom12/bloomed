import Foundation

enum BloomedRule {
    static let version = "bloomed.walk.v1"
    static let schemaVersion = 1
    static let currency = "CAD"
}

enum MoneyHandling: String, Codable, CaseIterable, Identifiable, Sendable {
    case participantRetains, anotherPersonHolds, otherArrangement
    var id: String { rawValue }
    var title: String {
        switch self {
        case .participantRetains: "I retain the funds"
        case .anotherPersonHolds: "Another person holds them"
        case .otherArrangement: "Other external arrangement"
        }
    }
}

struct ParticipantProfile: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var displayName = ""
    var privateMotivation = ""
    var progressionPromptsEnabled = true
    var createdAt = Date()
}

struct PlanTerms: Codable, Equatable, Sendable {
    var baseGoalSteps: Int
    var stretchGoalSteps: Int? = nil
    var consistencyEnabled = false
    var commitmentCents: Int
    var charity: String
    var handling: MoneyHandling = .participantRetains
    var handlerDescription = ""
    var currency = BloomedRule.currency
    var ruleVersion = BloomedRule.version

    var highestGoalSteps: Int { stretchGoalSteps ?? baseGoalSteps }
}

struct PlanDraft: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var baseGoalText = ""
    var stretchEnabled = false
    var stretchGoalText = ""
    var consistencyEnabled = false
    var commitmentText = ""
    var charity = ""
    var handling: MoneyHandling = .participantRetains
    var handlerDescription = ""
    var startDateKey: String
    var timezoneID: String
    var privateMotivation = ""
    var step = 0
    var createdAt = Date()
}

struct WeeklyPlan: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var startDateKey: String
    var timezoneID: String
    var dateKeys: [String]
    var terms: PlanTerms
    var createdAt: Date
    var confirmedAt: Date?
    var voidedAt: Date? = nil
    var dailyMaximumCents: [Int]
    var consistencyReserveCents: Int
}

enum PlanStatus: String, Codable, Sendable {
    case draft, scheduled, active, awaitingReview, reviewed, voidedBeforeStart
    var title: String {
        switch self {
        case .draft: "Draft"
        case .scheduled: "Upcoming"
        case .active: "In progress"
        case .awaitingReview: "Awaiting review"
        case .reviewed: "Reviewed"
        case .voidedBeforeStart: "Voided before start"
        }
    }
}

struct DailyStepRevision: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var dateKey: String
    var steps: Int?
    var source = "manual"
    var actorID: UUID
    var recordedAt: Date
    var supersedesID: UUID? = nil
    var reason = ""
    var transactionKey: UUID
}

struct SupportPerson: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var alias: String
    var createdAt: Date
}

struct SupportRelationship: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var personID: UUID
    var createdAt: Date
    var endedAt: Date? = nil
}

struct StandingAgreement: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var personID: UUID
    var relationshipID: UUID
    var capCents: Int
    var currency = BloomedRule.currency
    var effectiveStartDateKey: String
    var inclusiveEndDateKey: String? = nil
    var timezoneID: String
    var preservedTerms: PlanTerms
    var externallyAgreedDateKey: String
    var recordedAt: Date
    var recorderID: UUID
    var pausedAt: Date? = nil
    var endedAt: Date? = nil
}

struct WeeklySupportSnapshot: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var personID: UUID
    var relationshipID: UUID
    var alias: String
    var capCents: Int
    var currency = BloomedRule.currency
    var applies = true
    var wholeWeekAcknowledged: Bool
    var externallyAgreedDateKey: String
    var recordedAt: Date
    var recorderID: UUID
    var standingAgreementID: UUID? = nil
    var supersedesID: UUID? = nil
    var reason = ""
    var transactionKey: UUID
}

struct WeeklyAssessment: Codable, Equatable, Sendable {
    var dailyMaximumCents: [Int]
    var dailyBaseOnlyCents: [Int]
    var dailyReturnCents: [Int]
    var qualifyingDays: Int
    var highestGoalDays: Int
    var consistencyReserveCents: Int
    var consistencyReturnCents: Int
    var personalReturnCents: Int
    var charityAllocationCents: Int
    var supporterRewardCents: Int
    var unusedSupporterAllowanceCents: Int
}

struct AssessmentRevision: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var ruleVersion = BloomedRule.version
    var inputFingerprint: String
    var stepRevisionIDs: [UUID]
    var supportRevisionID: UUID? = nil
    var result: WeeklyAssessment
    var createdAt: Date
    var reviewedAt: Date? = nil
    var reviewerID: UUID? = nil
    var acknowledgedMissingDateKeys: [String] = []
    var supersedesID: UUID? = nil
    var transactionKey: UUID
}

enum FinancialBucket: String, Codable, CaseIterable, Identifiable, Sendable {
    case personalReturn, charityAllocation, supporterReward
    var id: String { rawValue }
    var title: String {
        switch self {
        case .personalReturn: "Your money earned back"
        case .charityAllocation: "Charity allocation"
        case .supporterReward: "Supporter rewards earned"
        }
    }
}

struct FinancialAssessmentEvent: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var assessmentID: UUID
    var bucket: FinancialBucket
    var deltaCents: Int
    var currency = BloomedRule.currency
    var createdAt: Date
    var actorID: UUID
    var transactionKey: String
}

struct ExternalSettlementRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var bucket: FinancialBucket
    var amountCents: Int
    var currency = BloomedRule.currency
    var effectiveDateKey: String
    var createdAt: Date
    var actorID: UUID
    var note = ""
    var voidedAt: Date? = nil
    var voidReason = ""
    var replacesID: UUID? = nil
    var transactionKey: UUID
}

enum AuditAction: String, Codable, Sendable {
    case planConfirmed = "PLAN_CONFIRMED"
    case planVoided = "PLAN_VOIDED"
    case entryRecorded = "ENTRY_RECORDED"
    case entryCorrected = "ENTRY_CORRECTED"
    case entryCleared = "ENTRY_CLEARED"
    case supportRecorded = "SUPPORT_RECORDED"
    case supportCorrected = "SUPPORT_CORRECTED"
    case assessmentReviewed = "ASSESSMENT_REVIEWED"
    case assessmentAdjusted = "ASSESSMENT_ADJUSTED"
    case settlementRecorded = "EXTERNAL_SETTLEMENT_RECORDED"
    case settlementVoided = "EXTERNAL_SETTLEMENT_VOIDED"
    case exceptionNoted = "EXCEPTION_NOTED"
    case resolutionNoted = "RESOLUTION_NOTED"
}

struct AuditEvent: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var entityID: UUID
    var action: AuditAction
    var createdAt: Date
    var actorID: UUID
    var reason = ""
    var beforeReference: UUID? = nil
    var afterReference: UUID? = nil
    var transactionKey: String
}

struct ExceptionRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var participantID: UUID
    var planID: UUID
    var note: String
    var createdAt: Date
    var actorID: UUID
    var resolvesID: UUID? = nil
    var transactionKey: UUID
}

struct BloomedState: Codable, Equatable, Sendable {
    var schemaVersion = BloomedRule.schemaVersion
    var profile = ParticipantProfile()
    var draft: PlanDraft? = nil
    var plans: [WeeklyPlan] = []
    var stepRevisions: [DailyStepRevision] = []
    var supportPeople: [SupportPerson] = []
    var relationships: [SupportRelationship] = []
    var standingAgreements: [StandingAgreement] = []
    var supportSnapshots: [WeeklySupportSnapshot] = []
    var assessments: [AssessmentRevision] = []
    var financialEvents: [FinancialAssessmentEvent] = []
    var settlements: [ExternalSettlementRecord] = []
    var auditEvents: [AuditEvent] = []
    var exceptions: [ExceptionRecord] = []
}

struct BackupEnvelope: Codable, Equatable, Sendable {
    var schemaVersion = BloomedRule.schemaVersion
    var application = "Bloomed"
    var exportedAt: Date
    var state: BloomedState
}
