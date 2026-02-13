import ArgumentParser

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Prints the software version."
    )
   
    mutating func run() throws {
        print("Version \(VersionInfo.version)")
        print("(c) 2026 SFW@EVVA Sicherheitstechnologie GmbH")
    }
}
