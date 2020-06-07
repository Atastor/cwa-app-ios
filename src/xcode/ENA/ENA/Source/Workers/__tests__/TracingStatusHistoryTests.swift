//
// Corona-Warn-App
//
// SAP SE and all other contributors /
// copyright owners license this file to you under the Apache
// License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.
//

import XCTest
@testable import ENA

final class TracingStatusHistoryTests: XCTestCase {
    func testTracingStatusHistory() throws {
		var history = TracingStatusHistory()
		XCTAssertTrue(history.isEmpty)
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)
		let badState = ExposureManagerState(authorized: true, enabled: false, status: .active)
		history = history.consumingState(badState)
		XCTAssertTrue(history.isEmpty)
		history = history.consumingState(goodState)
		XCTAssertEqual(history.count, 1)
		history = history.consumingState(goodState)
		history = history.consumingState(goodState)
		XCTAssertEqual(history.count, 1)
		history = history.consumingState(badState)
		XCTAssertEqual(history.count, 2)
    }

	// MARK: - TracingStatusHistory Pruning (discarding old items)

	func testPrune_Old() throws {
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)
		let badState = ExposureManagerState(authorized: true, enabled: false, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(.init(days: -15)))
		history = history.consumingState(badState, Date().addingTimeInterval(.init(days: -10)))
		history = history.consumingState(goodState, Date().addingTimeInterval(.init(days: -1)))
		history = history.consumingState(badState, Date().addingTimeInterval(.init(hours: -1)))

		XCTAssertEqual(history.count, 3)
	}

	func testPrune_KeepSingleItem() throws {
		// Test case when user has not changed exposure tracking for a long time
		// We should keep the oldest state (as long as it is good/on)
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(.init(days: -20)))

		XCTAssertEqual(history.count, 1)
	}

	// MARK: - TracingStatusHistory Risk Calculation Condition Checking
	// RiskLevel calculations require that tracing has been on for at least 48 hours

	func testIfTracingActiveForThresholdDuration_EnabledDistantPast() throws {
		// Test the simple case where the user enabled notification tracing,
		// and just left it enabled
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(.init(days: -20)))

		XCTAssertTrue(history.checkIfEnabled())
	}

	func testIfTracingActiveForThresholdDuration_DisabledDistantPast() throws {
		// Test the simple case where the user disabling notification tracing,
		// and just left it disabled
		var history = TracingStatusHistory()
		let badState = ExposureManagerState(authorized: true, enabled: false, status: .active)

		history = history.consumingState(badState, Date().addingTimeInterval(.init(days: -20)))

		XCTAssertFalse(history.checkIfEnabled())
	}

	func testIfTracingActiveForThresholdDuration_EnabledClosePast() throws {
		// Test the simple case where the user enabled notification tracing not too long ago,
		// and just left it enabled
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(.init(hours: -20)))

		XCTAssertFalse(history.checkIfEnabled())
	}

	func testIfTracingActiveForThresholdDuration_Toggled() throws {
		// Test the case where the user repeatedly enabled and disabled tracking
		var history = TracingStatusHistory()
		let badState = ExposureManagerState(authorized: true, enabled: false, status: .active)
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		var date = Date().addingTimeInterval(.init(hours: -50))

		// User enabled the tracing 50 hours ago
		history = history.consumingState(goodState, date)
		XCTAssertFalse(history.checkIfEnabled(since: date))

		date = date.addingTimeInterval(.init(hours: 1))

		// User turned it off after one hour - we've been tracing for one hour
		history = history.consumingState(badState, date)
		XCTAssertFalse(history.checkIfEnabled(since: date))

		date = date.addingTimeInterval(.init(hours: 2))

		// User leaves off for two hours - we've been tracing for one hour
		history = history.consumingState(goodState, date)
		XCTAssertFalse(history.checkIfEnabled(since: date))

		date = date.addingTimeInterval(.init(hours: 24))

		// User leaves it on for 24 hours - We've been tracking for 25 hours
		XCTAssertFalse(history.checkIfEnabled(since: date))

		// User leaves it on up and including until now
		XCTAssertTrue(history.checkIfEnabled())
	}

	// MARK: - Tracing enabled days tests

	func testEnabledDaysCount_EnabledDistantPast() throws {
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(.init(days: -10)))

		XCTAssertEqual(history.countEnabledDays(), 10)
	}

	func testEnabledDaysCount_EnabledRecently() throws {
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(-10))

		XCTAssertEqual(history.countEnabledDays(), 0)
	}

	func testEnabledHoursCount_EnabledRecently() throws {
		var history = TracingStatusHistory()
		let goodState = ExposureManagerState(authorized: true, enabled: true, status: .active)

		history = history.consumingState(goodState, Date().addingTimeInterval(-5400))
		// Enabled for 1.5 hours should only count as 1 enabled hour (truncating)
		XCTAssertEqual(history.countEnabledHours(), 1)
	}
}

private extension TimeInterval {
	init(hours: Int) {
		self = Double(hours * 60 * 60)
	}

	init(days: Int) {
		self = Double(days * 24 * 60 * 60)
	}
}
