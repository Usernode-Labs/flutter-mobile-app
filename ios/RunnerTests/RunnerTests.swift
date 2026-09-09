import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testOnlyForwardDeploymentMigrationMayRetainCredentials() {
    let old = "https://social-vibecoding.usernodelabs.org/api/v4/mobile"
    let next = "https://my.onhomeroom.com/api/v4/mobile"
    XCTAssertTrue(isHomeroomApiMigration(old, next))
    XCTAssertFalse(isHomeroomApiMigration(next, old))
    XCTAssertFalse(isHomeroomApiMigration(old, old))
    for other in [
      "https://staging.onhomeroom.com/api/v4/mobile",
      "https://my.onhomeroom.com.evil.test/api/v4/mobile",
      "http://my.onhomeroom.com/api/v4/mobile",
      "https://my.onhomeroom.com/other/api/v4/mobile",
      "\(next)?override=true",
    ] {
      XCTAssertFalse(isHomeroomApiMigration(old, other))
      XCTAssertFalse(isHomeroomApiMigration(other, next))
    }
  }

}
