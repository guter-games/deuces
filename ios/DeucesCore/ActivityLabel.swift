import Foundation

public enum ActivityLabel {
    /// Human-readable last-active label, e.g. "active just now", "2m ago".
    public static func format(
        lastActiveAt: Date?,
        claimed: Bool = true,
        now: Date = Date()
    ) -> String {
        guard claimed else { return "waiting to join" }
        guard let lastActiveAt else { return "not yet active" }
        let seconds = max(0, Int(now.timeIntervalSince(lastActiveAt)))

        if seconds < 60 {
            return "active just now"
        }
        if seconds < 3600 {
            let minutes = max(1, seconds / 60)
            return "\(minutes)m ago"
        }
        if seconds < 86_400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        }
        let days = seconds / 86_400
        return "\(days)d ago"
    }
}
