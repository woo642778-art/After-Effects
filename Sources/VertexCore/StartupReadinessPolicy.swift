import Foundation

public enum StartupReadinessPolicy {
    public static func shouldEnterApp(
        architectureContracts: [ArchitectureContract],
        milestone: Milestone
    ) -> Bool {
        !architectureContracts.isEmpty
            && milestone.number >= 0
            && !milestone.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
