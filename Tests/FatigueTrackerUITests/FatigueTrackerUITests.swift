import XCTest

final class FatigueTrackerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testLogNewEntryAppearsInHistory() throws {
        let quickLog = app.buttons["quick-log-button"]
        XCTAssertTrue(quickLog.waitForExistence(timeout: 5))
        quickLog.tap()

        let activityField = app.textFields["activity-field"]
        XCTAssertTrue(activityField.waitForExistence(timeout: 5))
        activityField.tap()
        activityField.typeText("test ride on the bike")

        app.buttons["form-save-button"].tap()

        // After saving, the form dismisses and the new row should appear.
        let firstRow = app.cells.firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["test ride on the bike"].exists)
    }

    func testSwipeToDeleteRemovesEntry() throws {
        // Seed one entry through the UI.
        app.buttons["quick-log-button"].tap()
        let activityField = app.textFields["activity-field"]
        XCTAssertTrue(activityField.waitForExistence(timeout: 5))
        activityField.tap()
        activityField.typeText("to be deleted")
        app.buttons["form-save-button"].tap()

        let row = app.staticTexts["to be deleted"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.swipeLeft()
        app.buttons["Delete"].tap()

        XCTAssertFalse(row.waitForExistence(timeout: 2))
    }

    func testExportButtonOpensShareSheet() throws {
        // Need at least one entry for Export to be enabled.
        app.buttons["quick-log-button"].tap()
        let activityField = app.textFields["activity-field"]
        XCTAssertTrue(activityField.waitForExistence(timeout: 5))
        activityField.tap()
        activityField.typeText("an entry to export")
        app.buttons["form-save-button"].tap()

        let exportButton = app.buttons["export-csv-button"]
        XCTAssertTrue(exportButton.waitForExistence(timeout: 5))
        exportButton.tap()

        // The system share sheet is presented as an activity list view.
        // We look for any of the common share sheet elements that appear.
        let shareSheet = app.otherElements["ActivityListView"]
            .firstMatch
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5)
                      || app.buttons["Copy"].waitForExistence(timeout: 2),
                      "Share sheet did not appear")
    }
}
