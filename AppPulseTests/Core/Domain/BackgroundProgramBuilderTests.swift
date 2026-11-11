import Testing
@testable import AppPulse

struct BackgroundProgramBuilderTests {
    private let slack = AppIdentity(id: "/Applications/Slack.app", name: "Slack", bundleIdentifier: "com.example.slack")
    private let menuBarTool = AppIdentity(id: "/Applications/Tool.app", name: "Tool", bundlePath: "/Applications/Tool.app", bundleIdentifier: "com.example.tool")

    private func process(_ app: AppIdentity, _ path: String?, memory: UInt64 = 0, readable: Bool = true) -> ProcessUsage {
        ProcessUsage(
            owner: ProcessOwner(app: app, processName: path.map { String($0.split(separator: "/").last ?? "") } ?? "?", executablePath: path),
            memoryBytes: memory,
            isReadable: readable
        )
    }

    @Test func appsWithAWindowAreLeftOut() {
        let programs = BackgroundProgramBuilder.build(
            [process(slack, "/Applications/Slack.app/Contents/MacOS/Slack"), process(.system, "/usr/libexec/agent")],
            foregroundBundleIdentifiers: ["com.example.slack"],
            signers: [:]
        )
        #expect(programs.map(\.path) == ["/usr/libexec/agent"])
    }

    @Test func menuBarAppsCountAsBackground() {
        let programs = BackgroundProgramBuilder.build(
            [process(menuBarTool, "/Applications/Tool.app/Contents/MacOS/Tool")],
            foregroundBundleIdentifiers: ["com.example.slack"],
            signers: [:]
        )
        #expect(programs.first?.bundlePath == "/Applications/Tool.app")
    }

    @Test func processesOfOneProgramAreCombined() {
        let programs = BackgroundProgramBuilder.build(
            [process(.system, "/usr/libexec/agent", memory: 100), process(.system, "/usr/libexec/agent", memory: 50, readable: false)],
            foregroundBundleIdentifiers: [],
            signers: ["/usr/libexec/agent": .apple]
        )
        #expect(programs.count == 1)
        #expect(programs.first?.processCount == 2)
        #expect(programs.first?.memoryBytes == 150)
        #expect(programs.first?.isReadable == true)
        #expect(programs.first?.signer == .apple)
    }

    @Test func programIsUnreadableOnlyWhenEveryProcessIs() {
        let programs = BackgroundProgramBuilder.build(
            [process(.system, "/Library/daemon", readable: false)],
            foregroundBundleIdentifiers: [],
            signers: [:]
        )
        #expect(programs.first?.isReadable == false)
        #expect(programs.first?.signer == nil)
    }

    @Test func processesWithoutAPathAreSkipped() {
        let programs = BackgroundProgramBuilder.build([process(.system, nil)], foregroundBundleIdentifiers: [], signers: [:])
        #expect(programs.isEmpty)
    }

    @Test(arguments: [(CodeSigner.unsigned, true), (.invalid, true), (.adHoc, true), (.apple, false), (.developer("Google LLC"), false), (.unknown, false)])
    func unverifiedSigners(signer: CodeSigner, expected: Bool) {
        #expect(signer.isUnverified == expected)
    }
}
