import Testing
@testable import Platform

struct AppPathClassifierTests {
    @Test func mainExecutableResolvesToItsApp() {
        #expect(AppPathClassifier.outermostAppBundle(in: "/Applications/Slack.app/Contents/MacOS/Slack") == "/Applications/Slack.app")
    }

    @Test func nestedHelperResolvesToOutermostApp() {
        let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Chrome Framework.framework/Helpers/Chrome Helper.app/Contents/MacOS/Chrome Helper"
        #expect(AppPathClassifier.outermostAppBundle(in: helper) == "/Applications/Google Chrome.app")
    }

    @Test func pathWithoutAppHasNoBundle() {
        #expect(AppPathClassifier.outermostAppBundle(in: "/usr/libexec/rapportd") == nil)
    }

    @Test func folderMerelyContainingAppTextIsNotABundle() {
        #expect(AppPathClassifier.outermostAppBundle(in: "/opt/my.apple/tool") == nil)
    }

    @Test func backgroundSystemBundlesAreSystem() {
        #expect(AppPathClassifier.isSystemBundle("/System/Library/CoreServices/ControlCenter.app"))
    }

    @Test func finderAndNormalAppsAreNotSystem() {
        #expect(!AppPathClassifier.isSystemBundle("/System/Library/CoreServices/Finder.app"))
        #expect(!AppPathClassifier.isSystemBundle("/System/Applications/Notes.app"))
        #expect(!AppPathClassifier.isSystemBundle("/Applications/Slack.app"))
    }
}
