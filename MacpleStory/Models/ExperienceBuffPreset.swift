//
//  ExperienceBuffPreset.swift
//  MacpleStory
//
//  앱 번들에 포함된 선택 가능한 버프 아이콘 프리셋.
//

import Foundation

struct ExperienceBuffPreset: Identifiable, Equatable {
    /// 파일명(확장자 제외). 프리셋 식별자이자 표시 이름.
    let id: String
    let displayName: String
    let iconTemplate: SkillIconTemplate
}
