import XCTest

/// End-to-end flows against a running dev server (`mix phx.server`).
///
/// Sign-in needs a fresh magic-link token from the server log, passed to the
/// test runner as TEST_RUNNER_MAGIC_TOKEN (xcodebuild strips the prefix):
///
///     TEST_RUNNER_MAGIC_TOKEN=… xcodebuild test -scheme Portermills …
final class PortermillsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Signs in through the magic link, then adds an event, adds and ticks a
    /// list item, adds a wishlist item and claims someone else's.
    func test1_SignInAndCoreFlows() throws {
        guard let token = ProcessInfo.processInfo.environment["MAGIC_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set TEST_RUNNER_MAGIC_TOKEN to a fresh magic-link token")
        }
        let suffix = ProcessInfo.processInfo.environment["ITEM_SUFFIX"] ?? "iOS"

        dismissSystemPrompt()
        app.launchArguments = ["--reset-session"]
        app.launch()

        // Request a link through the UI, then follow one.
        let email = app.textFields["login.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 10))
        email.tap()
        email.typeText("admin@portermills.app")
        app.buttons["login.send"].tap()
        XCTAssertTrue(app.staticTexts["Check your email"].waitForExistence(timeout: 10))

        // Open the link the way tapping it elsewhere would, and confirm the
        // system's "Open in Portermills?" prompt.
        XCUIDevice.shared.system.open(URL(string: "portermills://auth?token=\(token)")!)
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 5) { open.tap() }
        XCTAssertTrue(app.tabBars.buttons["Calendar"].waitForExistence(timeout: 15))

        // Calendar: add an event today.
        let eventTitle = "Haircut \(suffix)"
        app.buttons["calendar.add"].tap()
        let title = app.textFields["event.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(eventTitle)
        app.buttons["event.save"].tap()
        XCTAssertTrue(app.staticTexts[eventTitle].waitForExistence(timeout: 10))

        // Lists: add an item to the shopping list and tick it.
        let itemName = "Apples \(suffix)"
        app.tabBars.buttons["Lists"].tap()
        app.buttons["list.Shopping"].firstMatch.tap()
        let newItem = app.textFields["list.newItem"]
        XCTAssertTrue(newItem.waitForExistence(timeout: 5))
        newItem.tap()
        newItem.typeText(itemName + "\n")
        let item = app.buttons["item.\(itemName)"]
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        XCTAssertEqual(item.value as? String, "not ticked")
        item.tap()
        XCTAssertTrue(waitFor(item, value: "ticked"))

        // Wishlists: add to my own, then claim on Sam's.
        let wish = "Book \(suffix)"
        // Going back dismisses the keyboard, which covers the tab bar.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Wishlists"].tap()
        app.buttons["wishlist.My wishlist"].firstMatch.tap()
        app.buttons["wishlist.add"].tap()
        let wishName = app.textFields["wishItem.name"]
        XCTAssertTrue(wishName.waitForExistence(timeout: 5))
        wishName.tap()
        wishName.typeText(wish)
        app.buttons["wishItem.save"].tap()
        XCTAssertTrue(app.staticTexts[wish].waitForExistence(timeout: 10))
        // No claim controls on my own wishlist.
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'claim.'")).firstMatch.exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["wishlist.Sam's wishlist"].firstMatch.tap()
        let claim = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'claim.'")).firstMatch
        XCTAssertTrue(claim.waitForExistence(timeout: 10), "Sam's wishlist needs an unclaimed item")
        let claimedName = String(claim.identifier.dropFirst("claim.".count))
        claim.tap()
        XCTAssertTrue(app.buttons["release.\(claimedName)"].waitForExistence(timeout: 10))
    }

    /// Signs out from the account menu. Run after test1 (needs a signed-in app).
    func test2_SignOut() throws {
        app.launch()
        let menus = app.buttons.matching(identifier: "account.menu")
        guard menus.firstMatch.waitForExistence(timeout: 10) else { throw XCTSkip("Not signed in") }
        // Every tab has one; the first is the Calendar tab's, which is showing.
        // SwiftUI toolbar menus refuse XCUITest's scroll-to-visible, so tap the
        // element's position directly.
        menus.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["account.signOut"].tap()
        XCTAssertTrue(app.textFields["login.email"].waitForExistence(timeout: 10))
    }

    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    /// Clears an "Open in…?" prompt left over from an earlier run.
    private func dismissSystemPrompt() {
        let cancel = springboard.buttons["Cancel"]
        if cancel.exists { cancel.tap() }
    }

    private func waitFor(_ element: XCUIElement, value: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
