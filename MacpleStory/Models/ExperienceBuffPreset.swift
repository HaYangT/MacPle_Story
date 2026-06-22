//
//  ExperienceBuffPreset.swift
//  MacpleStory
//
//  앱 번들에 포함된 선택 가능한 버프 프리셋.
//  하나의 프리셋(그룹)은 여러 변형 아이콘을 가질 수 있다.
//  (예: "경험치버프" 그룹 = 2배 / 3배 / 4배 아이콘)
//  한 번에 하나만 활성화되는 버프라도 변형 중 아무거나 감지되면 활성으로 본다.
//

import Foundation

/// 그룹에 속한 개별 변형 아이콘.
struct BuffIconVariant: Identifiable, Equatable {
    /// 변형 이름(파일명의 `__` 뒤 부분, 단일이면 그룹명과 동일).
    let name: String
    let iconTemplate: SkillIconTemplate

    var id: String { name }
}

struct ExperienceBuffPreset: Identifiable, Equatable {
    /// 그룹 식별자. 표시 이름이자 추적 키.
    let id: String
    let displayName: String
    /// 목록 썸네일로 쓸 대표 변형.
    let representativeVariant: BuffIconVariant?
    /// 감지에 사용하는 모든 변형.
    let variants: [BuffIconVariant]
    /// 지속시간 옵션(분). 비어 있으면 "사라지면 알림", 있으면 "감지 후 (선택 시간 − 15초)에 알림".
    let durationsMinutes: [Int]

    init(
        id: String,
        displayName: String,
        variants: [BuffIconVariant],
        representativeVariant: BuffIconVariant? = nil,
        durationsMinutes: [Int] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.variants = variants
        self.representativeVariant = representativeVariant ?? variants.first
        self.durationsMinutes = durationsMinutes
    }

    /// 지속시간 기반 알림을 쓰는 버프인지.
    var isFixedDuration: Bool {
        !durationsMinutes.isEmpty
    }
}
