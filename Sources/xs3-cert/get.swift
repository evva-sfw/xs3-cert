import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFoundationCompat
import NIOSSL

struct Get: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Obtains the certificates from an XS3 instance."
    )

    @Argument(help: "The XS3 instance URL.")
    var xs3Url: String

    @Argument(help: "The username.")
    var username: String

    @Argument(help: "The password.")
    var password: String

    @Option(help: "The output path (defaults to ./out).")
    var outpath: String = "./out"

    @Option(help: "The timeout for web requests in seconds (defaults to 30).")
    var requestTimeout: Int64 = 30

    @Option(help: "The path for the process to be started after retrieving the certificates.")
    var startProcess: String = ""
    @Option(help: "The args for the to be started process.")
    var startProcessArgs: String = ""

    var XS_PATH_LOGIN: String = "api/v1/login"
    var XS_PATH_MQTTCONFIG: String = "api/v1/user/mqtt-configuration"

    mutating func run() async throws {
        let jsonDecoder = JSONDecoder()

        do {
            if #available(iOS 13, macOS 10.15, *) {
                // 1. Do Login
                let loginURL = "\(xs3Url)/\(XS_PATH_LOGIN)"
                let loginBody: String = "{\"name\": \"\(username)\",\"password\":\"\(password)\"}"
                print("Login at \(loginURL) as \(username)")

                // Do Login
                var request = HTTPClientRequest(url: loginURL)
                request.method = .POST
                request.headers.add(name: "Content-Type", value: "application/json")
                request.body = .bytes(ByteBuffer(string: loginBody))

                request.tlsConfiguration = TLSConfiguration.makeClientConfiguration()
                request.tlsConfiguration?.certificateVerification = .none

                let response = try await HTTPClient.shared.execute(
                    request, timeout: .seconds(requestTimeout))
                print("\(response.status)")
                var authToken: String = ""
                if response.status == .ok {
                    let body: ByteBuffer = try await response.body.collect(upTo: 2048)  // max 2k
                    let loginResponse = try! jsonDecoder.decode(LoginResponse.self, from: body)

                    authToken = loginResponse.token
                } else {
                    Get.exit(
                        withError: GetError(
                            kind: .login,
                            msg: "Login failed, please verify status code and reason.)"))
                }

                //2. Retrieve MQTT Client configuration
                let mqttConfigUrl = "\(xs3Url)/\(XS_PATH_MQTTCONFIG)"
                print("Retrieving MQTT client config at \(mqttConfigUrl)")
                var configRequest = HTTPClientRequest(url: mqttConfigUrl)
                configRequest.method = .GET
                configRequest.headers.add(name: "Content-Type", value: "application/json")
                configRequest.headers.add(name: "Authorization", value: "Bearer \(authToken)")

                configRequest.tlsConfiguration = TLSConfiguration.makeClientConfiguration()
                configRequest.tlsConfiguration?.certificateVerification = .none
                let configResponse = try await HTTPClient.shared.execute(
                    configRequest, timeout: .seconds(requestTimeout))
                print("\(configResponse.status)")
                if configResponse.status == .ok {

                    let configBody: ByteBuffer = try await configResponse.body.collect(
                        upTo: 1024 * 1024)  // max 1M
                    let mqttConfigResponse: MqttConfigResponse = try! jsonDecoder.decode(
                        MqttConfigResponse.self, from: configBody)

                    try mqttConfigResponse.ca.write(
                        toFile: "\(outpath)/ca.pem", atomically: true, encoding: .utf8)
                    try mqttConfigResponse.cert.write(
                        toFile: "\(outpath)/cert.pem", atomically: true, encoding: .utf8)
                    try mqttConfigResponse.key.write(
                        toFile: "\(outpath)/key.pem", atomically: true, encoding: .utf8)
                    let properties: String =
                        "userid=\(mqttConfigResponse.apiProperties.userId)\nbroker.address=\(mqttConfigResponse.apiProperties.brokerAddress)\nbroker.port=\(mqttConfigResponse.apiProperties.brokerPort)\ntoken=\(mqttConfigResponse.apiProperties.token)\n"
                    try properties.write(
                        toFile: "\(outpath)/api.properties", atomically: true, encoding: .utf8)

                } else {
                    Get.exit(
                        withError: GetError(
                            kind: .config,
                            msg:
                                "Retrieving MQTT client config failed, please verify status code and reason."
                        ))
                }

                //3. Start the process if requested
                if !startProcess.isEmpty {

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: startProcess)
                    print("Starting \(startProcess) \(startProcessArgs)")
                    if (!startProcessArgs.isEmpty) {
                        process.arguments = [startProcessArgs]
                    }
                    try! process.run()
                    process.waitUntilExit()
                    print("Finished executing \(startProcess) \(startProcessArgs)")
                }

            }
        } catch {
            Get.exit(withError: GetError(kind: .connection, msg: "\(error)"))
        }
    }
}

struct LoginResponse: Decodable {
    let id: String
    let token: String
    let installationUser: Bool
    let role: String
    let partitionId: String
    let loginState: String
}

struct ApiProperties: Decodable {
    let userId: String
    let brokerAddress: String
    let brokerPort: Int
    let token: String
}

struct MqttConfigResponse: Decodable {
    let ca: String
    let cert: String
    let key: String
    let apiProperties: ApiProperties
}

struct GetError: Error {

    enum Kind {
        case connection
        case login
        case config
    }

    let kind: Kind
    let msg: String
}
