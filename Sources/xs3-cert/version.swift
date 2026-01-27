import ArgumentParser

struct Version: ParsableCommand  {
    static let version: String = "1.2.0";
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Prints the software version."
    )
   
    mutating func run() throws {
        print("Version \(Version.version)")
        print("(c) 2026 SFW@EVVA Sicherheitstechnologie GmbH")
    }
}
