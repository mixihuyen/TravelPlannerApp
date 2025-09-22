struct VerifyOTPResponse: Decodable {
    let success: Bool
    let message: String
    let statusCode: Int
    let reasonStatusCode: String
    let data: VerifyOTPData?

    struct VerifyOTPData: Decodable {
        let token: Token
        let user: UserInformation

        struct Token: Decodable {
            let accessToken: String
            let refreshToken: String
        }
    }
}
struct RefreshTokenResponse: Codable {
        let success: Bool
        let message: String
        let statusCode: Int
        let reasonStatusCode: String
        let data: TokenData
        
        struct TokenData: Codable {
            let token: Token
            struct Token: Codable {
                let accessToken: String
                let refreshToken: String
            }
        }
    }
