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

    @Option(help: "The path of the file to read the parameters from.") 
    var paramsFile: String = ""

    @Option(help: "The XS3 instance URL.")
    var xs3Url: String = ""

    @Option(help: "The username.")
    var username: String = ""

    @Option(help: "The password.")
    var password: String = ""

    @Option(help: "The output path (defaults to ./out).")
    var outpath: String = "./out"

    @Option(help: "The timeout for web requests in seconds (defaults to 30).")
    var requestTimeout: Int64 = 30

    @Option(help: "The path for the process to be started after retrieving the certificates.")
    var startProcess: String = ""

    @Option(help: "The args for the to be started process.")
    var startProcessArgs: String = ""

    var XSPathLogin: String = "api/v1/login"
    var XSPathMqttConfig: String = "api/v1/user/mqtt-configuration"

    func readKeyValueFile(atPath path: String) -> [String: String] {
      var dict = [String: String]()
    
      do {
        // 1. Read the file content
        let content = try String(contentsOfFile: path, encoding: .utf8)
        
        // 2. Split by newlines
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // Skip empty lines or lines without '='
            if line.isEmpty || !line.contains("=") { continue }
            
            // 3. Split each line into key and value
            let parts = line.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                dict[key] = value
            }
        }
      } catch {
        print("Error reading file: \(error)")
      }
    
      return dict
    }

    mutating func run() async throws {
        let jsonDecoder = JSONDecoder()

        do {
            if #available(iOS 13, macOS 10.15, *) {
                if !paramsFile.isEmpty { let params = readKeyValueFile(atPath: paramsFile)
                xs3Url = params["XS3_URL"] ?? xs3Url
                username = params["USERNAME"] ?? username
                password = params["PASSWORD"] ?? password
                outpath = params["OUTPATH"] ?? outpath
                requestTimeout = Int64(params["REQUEST_TIMEOUT"] ?? String(requestTimeout)) ?? requestTimeout
                startProcess = params["START_PROCESS"] ?? startProcess
                startProcessArgs = params["START_PROCESS_ARGS"] ?? startProcessArgs }
                print("Using parameters from params file: \(paramsFile)")
                // 1. Do Login
                let loginURL = "\(xs3Url)/\(XSPathLogin)"
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
                    let loginResponse = try jsonDecoder.decode(LoginResponse.self, from: body)

                    authToken = loginResponse.token
                } else {
                    Get.exit(
                        withError: GetError(
                            kind: .login,
                            msg: "Login failed, please verify status code and reason.)"))
                }

                // 2. Retrieve MQTT Client configuration
                let mqttConfigUrl = "\(xs3Url)/\(XSPathMqttConfig)"
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
                    let mqttConfigResponse: MqttConfigResponse = try jsonDecoder.decode(
                        MqttConfigResponse.self, from: configBody)

                    try mqttConfigResponse.ca.write(
                        toFile: "\(outpath)/ca.pem", atomically: true, encoding: .utf8)
                    try mqttConfigResponse.cert.write(
                        toFile: "\(outpath)/mqtt.pem", atomically: true, encoding: .utf8)
                    try mqttConfigResponse.key.write(
                        toFile: "\(outpath)/mqtt.key", atomically: true, encoding: .utf8)
                    let properties: String =
                        "userid=\(mqttConfigResponse.apiProperties.userId)\n" + 
                        "broker.address=\(mqttConfigResponse.apiProperties.brokerAddress)\n" + 
                        "broker.port=\(mqttConfigResponse.apiProperties.brokerPort)\n" + 
                        "token=\(mqttConfigResponse.apiProperties.token)\n" + 
                        "backend.address=\((xs3Url))\n"
                    try properties.write(
                        toFile: "\(outpath)/mqtt.properties", atomically: true, encoding: .utf8)

                } else {
                    Get.exit(
                        withError: GetError(
                            kind: .config,
                            msg:
                                "Retrieving MQTT client config failed, please verify status code and reason."
                        ))
                }

                // 3. Start the process if requested
                if !startProcess.isEmpty {

                    let process = Process()
                    let pipe: Pipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = pipe  // Often useful to catch errors too

                    process.executableURL = URL(fileURLWithPath: startProcess)
                    // Set up a read handler to print output in real-time
                    pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                        let data = fileHandle.availableData
                        if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                            print(string, terminator: "")  // Print directly to current stdout
                        }
                    }
                    print("Starting \(startProcess) \(startProcessArgs)")
                    if !startProcessArgs.isEmpty {
                        process.arguments = [startProcessArgs]
                    }
                    do {
                        try process.run()
                        process.waitUntilExit()
                        print("Finished executing \(startProcess) \(startProcessArgs)")
                        // Cleanup handler
                        pipe.fileHandleForReading.readabilityHandler = nil
                    } catch {
                        print("Failed to execute process \(startProcess) \(startProcessArgs): \(error)")
                    }
                }

            }
        } catch {
            Get.exit(withError: GetError(kind: .connection, msg: "\(error)"))
        }
    }
}
