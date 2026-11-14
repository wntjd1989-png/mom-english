import Foundation
import Security

/// Wi-Fi 비밀번호 저장소.
///
/// 평문이 `UserDefaults`/백업 파일에 남지 않도록 키체인에만 넣습니다.
/// 접근 그룹을 App Group 으로 지정해서 앱 본체와 위젯 확장이 같은 항목을 읽습니다.
///
/// 접근 수준은 `kSecAttrAccessibleAfterFirstUnlock` 입니다.
/// 잠금화면 컨트롤에서 연결을 눌렀을 때도 비밀번호를 읽을 수 있어야 하기 때문에
/// `WhenUnlocked` 가 아니라 `AfterFirstUnlock` 을 씁니다.
/// (부팅 후 한 번이라도 잠금을 푼 적이 있으면 읽힙니다.)
enum KeychainStore {

    private static let service = "\(AppGroup.bundleRoot).passphrase"

    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String? ?? "알 수 없는 오류"
                return "키체인 오류 (\(status)): \(message)"
            }
        }
    }

    private static func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrAccessGroup as String: AppGroup.keychainAccessGroup,
        ]
    }

    /// 비밀번호를 저장합니다. `nil` 또는 빈 문자열을 넘기면 기존 항목을 지웁니다.
    static func setPassphrase(_ passphrase: String?, for id: UUID) throws {
        guard let passphrase, !passphrase.isEmpty else {
            delete(id: id)
            return
        }
        guard let data = passphrase.data(using: .utf8) else { return }

        var query = baseQuery(for: id)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainError.unexpectedStatus(updateStatus)
    }

    /// 저장된 비밀번호를 읽습니다. 없으면 `nil`.
    static func passphrase(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(id: UUID) {
        SecItemDelete(baseQuery(for: id) as CFDictionary)
    }
}
