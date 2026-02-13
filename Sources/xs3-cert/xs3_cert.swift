import ArgumentParser
@main
@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct XS3cert: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xs3-cert",
        abstract: "An utility for obtaining certificates from an XS3 API.",
        subcommands: [Version.self, Get.self])
}
