import XCTest
import AIScan

final class PublicSourceCompatibilityTests: XCTestCase {
    @MainActor
    func testConfigureIsAvailableToOrdinaryImportsWithAndWithoutEnvironment() {
        defer { AIScanManager.clearConfiguration() }
        AIScanManager.configure(publishableKey: "pk_example")
        AIScanManager.configure(publishableKey: "pk_example", environment: .production)
        let environment: AIScanEnvironment = .development
        AIScanManager.configure(publishableKey: "pk_example", environment: environment)
    }
}
