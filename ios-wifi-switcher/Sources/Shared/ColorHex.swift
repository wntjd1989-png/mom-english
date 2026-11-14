import SwiftUI

extension Color {
    /// "#RRGGBB" 또는 "RRGGBB" 문자열에서 색을 만듭니다. 잘못된 값이면 파란색으로 폴백합니다.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self = Color(red: 10 / 255, green: 132 / 255, blue: 1)
            return
        }

        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// 네트워크 편집 화면에서 고를 수 있는 색 팔레트.
enum NetworkPalette {
    static let hexes = [
        "#0A84FF", // 파랑
        "#30D158", // 초록
        "#FF9F0A", // 주황
        "#FF375F", // 빨강
        "#BF5AF2", // 보라
        "#64D2FF", // 하늘
        "#FFD60A", // 노랑
        "#8E8E93", // 회색
    ]

    /// 위젯 버튼 아이콘으로 쓸 SF Symbols 후보.
    static let symbols = [
        "wifi",
        "house.fill",
        "building.2.fill",
        "briefcase.fill",
        "cup.and.saucer.fill",
        "bed.double.fill",
        "airplane",
        "car.fill",
        "iphone",
        "antenna.radiowaves.left.and.right",
    ]
}
