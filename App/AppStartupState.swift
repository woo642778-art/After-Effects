import Foundation

enum AppStartupState: Equatable, Sendable {
    case splash
    case workspace
    case fatalConfigurationError(String)
}

struct AppStartupPolicy: Sendable {
    static let fatalUIMessage = "Required UI resources are unavailable."

    /// Startup readiness must be independent of milestone/phase, AI model state,
    /// Metal availability, recent-project health, and other optional subsystems.
    static func terminalState(bundleUIAvailable: Bool) -> AppStartupState {
        bundleUIAvailable
            ? .workspace
            : .fatalConfigurationError(fatalUIMessage)
    }

    /// Kept explicit so regression tests can prove arbitrary future phase values
    /// never become launch gates again.
    static func terminalState(bundleUIAvailable: Bool, milestoneNumber _: Int) -> AppStartupState {
        terminalState(bundleUIAvailable: bundleUIAvailable)
    }
}
