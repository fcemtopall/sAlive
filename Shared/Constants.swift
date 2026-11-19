import Foundation

enum SAlive {
    /// Apple Developer Team ID. The helper only accepts XPC connections from
    /// binaries signed by this team. Forks must change this (and project.yml).
    static let teamID = "NBADP4RFZ4"

    static let appBundleID = "io.github.fcemtopall.salive"
    static let helperMachService = "io.github.fcemtopall.salive.helper"
    static let helperPlistName = "io.github.fcemtopall.salive.helper.plist"
    static let changedNotification = "io.github.fcemtopall.salive.changed"
    static let controlKind = "io.github.fcemtopall.salive.control"

    static let codeSigningRequirement =
        "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\""

    /// Upper bound for a timed keep-awake session (7 days).
    static let maxDuration: TimeInterval = 7 * 24 * 3600
}
