import KomentCore
import Foundation
import Testing

@Suite("Paths")
struct PathsTests {
    let paths = Paths()

    @Test("every file the app owns lives in one folder named after the bundle")
    func supportDirectory() {
        #expect(paths.supportDirectory.lastPathComponent == "com.nandzz.koment")
        #expect(paths.supportDirectory.path.contains("Application Support"))
    }

    @Test("the four things the app writes each have their own name")
    func names() {
        #expect(paths.databaseURL.lastPathComponent == "comments.db")
        #expect(paths.configURL.lastPathComponent == "config.json")
        #expect(paths.diagnosticsURL.lastPathComponent == "diagnostics.log")
        #expect(paths.runsDirectory.lastPathComponent == "runs")
    }

    @Test("they all sit directly inside the support folder")
    func parents() {
        let parent = paths.supportDirectory.path
        #expect(paths.databaseURL.deletingLastPathComponent().path == parent)
        #expect(paths.configURL.deletingLastPathComponent().path == parent)
        #expect(paths.diagnosticsURL.deletingLastPathComponent().path == parent)
        #expect(paths.runsDirectory.deletingLastPathComponent().path == parent)
    }

    @Test("preparing the folder is safe to repeat")
    func prepare() throws {
        try paths.prepare()
        try paths.prepare()
        #expect(FileManager.default.fileExists(atPath: paths.supportDirectory.path))
    }

    @Test("nothing the app owns is written inside a project")
    func nothingInProjects() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        #expect(paths.supportDirectory.path.hasPrefix(home + "/Library"))
    }
}
