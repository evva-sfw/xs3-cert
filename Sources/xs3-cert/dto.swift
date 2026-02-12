import Foundation

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
    // swiftlint:disable identifier_name 
    let ca: String
    // swiftlint:enable identifier_name
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
