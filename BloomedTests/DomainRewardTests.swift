import XCTest
@testable import Bloomed

final class DomainRewardTests: XCTestCase {
    private struct Fixtures: Decodable {
        var cases: [Fixture]
    }
    private struct Fixture: Decodable {
        var id: String
        var description: String
        var input: Input
        var expected: Expected
    }
    private struct Input: Decodable {
        var personalCommitmentCents: Int
        var baseGoalSteps: Int
        var stretchGoalSteps: Int?
        var consistencyEnabled: Bool
        var dailySteps: [Int?]
        var supporterCapCents: Int?
    }
    private struct Expected: Decodable {
        var dailyMaximumCents: [Int]
        var dailyReturnCents: [Int]
        var qualifyingDays: Int
        var consistencyReserveCents: Int
        var consistencyReturnCents: Int
        var personalReturnCents: Int
        var charityAllocationCents: Int
        var supporterRewardCents: Int
        var unusedSupporterAllowanceCents: Int
    }

    private func terms(commitment: Int = 3500, stretch: Int? = 8000, consistency: Bool = true) -> PlanTerms {
        PlanTerms(baseGoalSteps: 5000, stretchGoalSteps: stretch, consistencyEnabled: consistency,
                  commitmentCents: commitment, charity: "Chosen charity")
    }

    func testAll28AuthoredNumericalFixtures() throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "reward-cases", withExtension: "json"), "The specification fixture must be copied into the test bundle.")
        let fixtures = try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixtures.cases.count, 28)
        XCTAssertEqual(Set(fixtures.cases.map(\.id)).count, 28)
        for fixture in fixtures.cases {
            let input = fixture.input
            let value = try RewardEngine.evaluate(terms: PlanTerms(baseGoalSteps: input.baseGoalSteps, stretchGoalSteps: input.stretchGoalSteps,
                                                                 consistencyEnabled: input.consistencyEnabled, commitmentCents: input.personalCommitmentCents,
                                                                 charity: "Chosen charity"), dailySteps: input.dailySteps, supporterCapCents: input.supporterCapCents)
            let expected = fixture.expected
            let message = "\(fixture.id): \(fixture.description)"
            XCTAssertEqual(value.dailyMaximumCents, expected.dailyMaximumCents, message)
            XCTAssertEqual(value.dailyReturnCents, expected.dailyReturnCents, message)
            XCTAssertEqual(value.qualifyingDays, expected.qualifyingDays, message)
            XCTAssertEqual(value.consistencyReserveCents, expected.consistencyReserveCents, message)
            XCTAssertEqual(value.consistencyReturnCents, expected.consistencyReturnCents, message)
            XCTAssertEqual(value.personalReturnCents, expected.personalReturnCents, message)
            XCTAssertEqual(value.charityAllocationCents, expected.charityAllocationCents, message)
            XCTAssertEqual(value.supporterRewardCents, expected.supporterRewardCents, message)
            XCTAssertEqual(value.unusedSupporterAllowanceCents, expected.unusedSupporterAllowanceCents, message)
        }
    }

    func testFullReturnConservationAndMonotonicityAcrossConfigurations() throws {
        let commitments = [100, 101, 103, 111, 999, 1000, 3500, 3503, 99999, 100000]
        let inputs: [[Int?]] = [Array(repeating: nil, count: 7), Array(repeating: 0, count: 7),
                               [0, 4999, 5000, 7999, 8000, 10000, nil], [5000, 0, 5000, 8000, nil, 8000, 5000]]
        for commitment in commitments {
            for stretch: Int? in [nil, 8000] {
                for consistency in [false, true] {
                    let terms = terms(commitment: commitment, stretch: stretch, consistency: consistency)
                    let perfect = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: terms.highestGoalSteps, count: 7), supporterCapCents: 100_000)
                    XCTAssertEqual(perfect.personalReturnCents, commitment)
                    XCTAssertEqual(perfect.charityAllocationCents, 0)
                    XCTAssertEqual(perfect.dailyMaximumCents.reduce(0, +) + perfect.consistencyReserveCents, commitment)
                    for input in inputs {
                        let original = try RewardEngine.evaluate(terms: terms, dailySteps: input, supporterCapCents: 700)
                        XCTAssertEqual(original.personalReturnCents + original.charityAllocationCents, commitment)
                        XCTAssertEqual(original.supporterRewardCents + original.unusedSupporterAllowanceCents, 700)
                        XCTAssertTrue((0...commitment).contains(original.personalReturnCents))
                        XCTAssertEqual(try RewardEngine.evaluate(terms: terms, dailySteps: input, supporterCapCents: 700), original)
                        for index in 0..<7 {
                            var raised = input
                            raised[index] = 100_000
                            let increased = try RewardEngine.evaluate(terms: terms, dailySteps: raised, supporterCapCents: 700)
                            XCTAssertGreaterThanOrEqual(increased.personalReturnCents, original.personalReturnCents)
                            XCTAssertGreaterThanOrEqual(increased.supporterRewardCents, original.supporterRewardCents)
                        }
                    }
                }
            }
        }
    }

    func testQualificationDoesNotDependOnCommitmentOrSupport() throws {
        let input: [Int?] = [5000, 8000, 0, nil, 10000, 4999, 5000]
        let low = try RewardEngine.evaluate(terms: terms(commitment: 100), dailySteps: input)
        let high = try RewardEngine.evaluate(terms: terms(commitment: 100000), dailySteps: input, supporterCapCents: 90000)
        XCTAssertEqual(low.qualifyingDays, high.qualifyingDays)
        XCTAssertEqual(low.highestGoalDays, high.highestGoalDays)
        XCTAssertEqual(low.qualifyingDays, 4)
        XCTAssertEqual(low.highestGoalDays, 2)
    }

    func testActiveForecastIncludesCurrentDayAndAvoidsDoubleCountingConsistency() throws {
        let start = try RewardEngine.forecast(terms: terms(), dailySteps: Array(repeating: nil, count: 7), closedDayCount: 0)
        XCTAssertEqual(start.earnedSoFarCents, 0)
        XCTAssertEqual(start.maximumAttainableCents, 3500)
        XCTAssertEqual(start.remainingWalkingOpportunityCents, 3500)
        let fifthDay = try RewardEngine.forecast(terms: terms(), dailySteps: [8000, 8000, 8000, 8000, 0, 0, 5000], closedDayCount: 6)
        XCTAssertEqual(fifthDay.earnedSoFarCents, 2400)
        XCTAssertEqual(fifthDay.maximumAttainableCents, 2700)
        XCTAssertEqual(fifthDay.remainingWalkingOpportunityCents, 300)
        let impossible = try RewardEngine.forecast(terms: terms(), dailySteps: [8000, 8000, 8000, 0, 0, 0, 8000], closedDayCount: 6)
        XCTAssertEqual(impossible.earnedSoFarCents, 1600)
        XCTAssertEqual(impossible.maximumAttainableCents, 1600)
        XCTAssertEqual(impossible.remainingWalkingOpportunityCents, 0)
        XCTAssertEqual(impossible.attainableConsistencyCents, 0)
        let ended = try RewardEngine.forecast(terms: terms(), dailySteps: [8000, nil, nil, nil, nil, nil, nil], closedDayCount: 7)
        XCTAssertEqual(ended.remainingWalkingOpportunityCents, 0)
        XCTAssertEqual(ended.maximumAttainableCents, 400)
    }

    func testMissingAndZeroHaveSameQualificationButRemainDifferentInputs() throws {
        let missing: [Int?] = [nil, nil, nil, nil, nil, nil, nil]
        let zero: [Int?] = [0, 0, 0, 0, 0, 0, 0]
        XCTAssertNotEqual(missing, zero)
        XCTAssertEqual(try RewardEngine.evaluate(terms: terms(), dailySteps: missing), try RewardEngine.evaluate(terms: terms(), dailySteps: zero))
    }

    func testCorrectionRemovesConsistencyAndMatchWithoutChangingPriorValue() throws {
        let old = try RewardEngine.evaluate(terms: terms(), dailySteps: [5000, 5000, 5000, 5000, 5000, 0, 0], supporterCapCents: 1000)
        let new = try RewardEngine.evaluate(terms: terms(), dailySteps: [5000, 5000, 5000, 5000, 0, 0, 0], supporterCapCents: 1000)
        XCTAssertEqual(old.personalReturnCents, 1200)
        XCTAssertEqual(new.personalReturnCents, 400)
        XCTAssertEqual(new.personalReturnCents - old.personalReturnCents, -800)
        XCTAssertEqual(new.charityAllocationCents - old.charityAllocationCents, 800)
        XCTAssertEqual(new.supporterRewardCents - old.supporterRewardCents, -600)
        XCTAssertEqual(Reconciliation(targetCents: new.personalReturnCents, recordedCents: 1200).excessRecordedCents, 800)
        XCTAssertEqual(Reconciliation(targetCents: new.charityAllocationCents, recordedCents: 2300).outstandingCents, 800)
    }

    func testInvalidInputsAndUnsupportedRulesAreRejected() throws {
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(commitment: 99), dailySteps: Array(repeating: nil, count: 7)))
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(commitment: Int.max), dailySteps: Array(repeating: nil, count: 7)))
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(), dailySteps: [0]))
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(), dailySteps: [0, 0, 0, 0, 0, 0, -1]))
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(), dailySteps: Array(repeating: 100001, count: 7)))
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: terms(), dailySteps: Array(repeating: nil, count: 7), supporterCapCents: 0))
        var invalid = terms()
        invalid.ruleVersion = "unsupported"
        XCTAssertThrowsError(try RewardEngine.evaluate(terms: invalid, dailySteps: Array(repeating: nil, count: 7)))
    }

    func testExactMoneyParsingRejectsAmbiguityFractionalCentsAndOverflow() throws {
        XCTAssertEqual(try Money.parseCents("1"), 100)
        XCTAssertEqual(try Money.parseCents("1.1"), 110)
        XCTAssertEqual(try Money.parseCents("1000.00"), 100000)
        XCTAssertEqual(try Money.parseCents(" 35.03 "), 3503)
        for invalid in ["", "-1", "+1", "1.001", "1,00", "1,000.00", "1.", ".5", "1e2", "$1", "NaN", "999999999999999999999999999999", "١.٠٠"] {
            XCTAssertThrowsError(try Money.parseCents(invalid), invalid)
        }
    }
}
