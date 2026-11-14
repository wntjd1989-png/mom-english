import Foundation

/// 공유기 라벨이나 게스트 안내문에 붙어 있는 Wi-Fi QR 코드를 해석합니다.
///
/// 표준 포맷(WPA 가 정의한 `WIFI:` 스킴):
/// ```
/// WIFI:T:WPA;S:MyNetwork;P:mypassword;H:false;;
/// ```
/// - `T` : 보안 방식 (`WPA` / `WEP` / `nopass`)
/// - `S` : SSID
/// - `P` : 비밀번호
/// - `H` : 숨겨진 네트워크 여부
///
/// SSID·비밀번호에 `;` `:` `,` `\` 가 들어가면 백슬래시로 이스케이프됩니다.
enum WiFiQRParser {

    struct Result: Equatable {
        var ssid: String
        var passphrase: String?
        var security: WiFiSecurity
        var isHidden: Bool
    }

    static func parse(_ payload: String) -> Result? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // 스킴은 대소문자를 가리지 않습니다 (WIFI:, wifi:, WiFi: 모두 허용).
        guard trimmed.count > 5 else { return nil }
        let prefix = trimmed.prefix(5)
        guard prefix.lowercased() == "wifi:" else { return nil }

        let body = String(trimmed.dropFirst(5))
        let fields = splitFields(body)

        var ssid: String?
        var passphrase: String?
        var security: WiFiSecurity = .wpa
        var isHidden = false

        for field in fields {
            // 키는 ':' 앞의 한두 글자. 값에 ':' 가 있을 수 있으므로 첫 ':' 에서만 자릅니다.
            guard let separator = field.firstIndex(of: ":") else { continue }
            let key = String(field[field.startIndex..<separator]).uppercased()
            let rawValue = String(field[field.index(after: separator)...])
            let value = unescape(rawValue)

            switch key {
            case "S":
                ssid = value
            case "P":
                passphrase = value
            case "T":
                switch value.uppercased() {
                case "NOPASS", "":
                    security = .open
                case "WEP":
                    security = .wep
                default:
                    // WPA, WPA2, WPA3, SAE 등은 모두 같은 생성자를 씁니다.
                    security = .wpa
                }
            case "H":
                isHidden = (value.lowercased() == "true" || value == "1")
            default:
                break
            }
        }

        guard let ssid, !ssid.isEmpty else { return nil }

        // 비밀번호가 없으면 보안 방식과 무관하게 개방형으로 취급합니다.
        if passphrase?.isEmpty ?? true {
            return Result(ssid: ssid, passphrase: nil, security: .open, isHidden: isHidden)
        }

        return Result(ssid: ssid, passphrase: passphrase, security: security, isHidden: isHidden)
    }

    /// 이스케이프되지 않은 `;` 기준으로 필드를 나눕니다.
    private static func splitFields(_ body: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var isEscaped = false

        for character in body {
            if isEscaped {
                // 이스케이프 표시는 unescape 단계에서 처리하도록 그대로 넘깁니다.
                current.append("\\")
                current.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            if character == ";" {
                if !current.isEmpty { fields.append(current) }
                current = ""
                continue
            }
            current.append(character)
        }
        if isEscaped { current.append("\\") }
        if !current.isEmpty { fields.append(current) }
        return fields
    }

    private static func unescape(_ value: String) -> String {
        var result = ""
        var isEscaped = false
        for character in value {
            if isEscaped {
                result.append(character)
                isEscaped = false
                continue
            }
            if character == "\\" {
                isEscaped = true
                continue
            }
            result.append(character)
        }
        return result
    }
}
