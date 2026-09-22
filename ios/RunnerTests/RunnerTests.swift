import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testOnlyForwardDeploymentMigrationMayRetainCredentials() {
    let legacy = "https://social-vibecoding.usernodelabs.org/api/v4/mobile"
    let interim = "https://my.onhomeroom.com/api/v4/mobile"
    let current = "https://app.onhomeroom.com/api/v4/mobile"
    XCTAssertTrue(isHomeroomApiMigration(legacy, interim))
    XCTAssertTrue(isHomeroomApiMigration(legacy, current))
    XCTAssertTrue(isHomeroomApiMigration(interim, current))
    XCTAssertFalse(isHomeroomApiMigration(current, interim))
    XCTAssertFalse(isHomeroomApiMigration(current, legacy))
    XCTAssertFalse(isHomeroomApiMigration(current, current))
    for other in [
      "https://staging.onhomeroom.com/api/v4/mobile",
      "https://app.onhomeroom.com.evil.test/api/v4/mobile",
      "http://app.onhomeroom.com/api/v4/mobile",
      "https://app.onhomeroom.com/other/api/v4/mobile",
      "\(current)?override=true",
    ] {
      XCTAssertFalse(isHomeroomApiMigration(legacy, other))
      XCTAssertFalse(isHomeroomApiMigration(interim, other))
      XCTAssertFalse(isHomeroomApiMigration(other, current))
    }
  }

}
