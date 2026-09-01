import XCTest
@testable import veralify

final class OnboardingStateMachineXCTests: XCTestCase {
    func testForwardTransitionsFollowSpecOrder() {
        XCTAssertEqual(OnboardingStateMachine.next(after: .welcome), .goalSelection)
        XCTAssertEqual(OnboardingStateMachine.next(after: .goalSelection), .profileSetup)
        XCTAssertEqual(OnboardingStateMachine.next(after: .profileSetup), .targetSetup)
        XCTAssertEqual(OnboardingStateMachine.next(after: .targetSetup), .planReveal)
        XCTAssertEqual(OnboardingStateMachine.next(after: .planReveal), .paywall)
        XCTAssertEqual(OnboardingStateMachine.next(after: .paywall), .communitySetup)
        XCTAssertNil(OnboardingStateMachine.next(after: .communitySetup))
    }

    func testBackwardTransitionsFollowSpecOrder() {
        XCTAssertEqual(OnboardingStateMachine.previous(before: .communitySetup), .paywall)
        XCTAssertEqual(OnboardingStateMachine.previous(before: .paywall), .planReveal)
        XCTAssertEqual(OnboardingStateMachine.previous(before: .planReveal), .targetSetup)
        XCTAssertEqual(OnboardingStateMachine.previous(before: .targetSetup), .profileSetup)
        XCTAssertEqual(OnboardingStateMachine.previous(before: .profileSetup), .goalSelection)
        XCTAssertEqual(OnboardingStateMachine.previous(before: .goalSelection), .welcome)
        XCTAssertNil(OnboardingStateMachine.previous(before: .welcome))
    }
}
