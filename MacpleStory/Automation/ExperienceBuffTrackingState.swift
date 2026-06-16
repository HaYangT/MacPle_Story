//
//  ExperienceBuffTrackingState.swift
//  MacpleStory
//

import Foundation

enum ExperienceBuffTrackingState {
    /// 아직 버프가 한 번도 감지되지 않은 상태 (시작 직후 또는 알림 후 재활성 대기)
    case waitingForActivation
    /// 버프가 활성 상태
    case active
    /// 버프가 사라진 것으로 보이나 아직 확인 중 (연속 미감지 프레임 카운트)
    case confirmingInactive(count: Int)
    /// 버프 종료 확정 → 알림 발송 완료, 재활성화 대기
    case alertedInactive

    var isAlertedInactive: Bool {
        if case .alertedInactive = self { return true }
        return false
    }

    /// 다음 상태와 알림 발송 여부를 반환
    func transition(
        isActive: Bool,
        missingFrameThreshold: Int
    ) -> (next: ExperienceBuffTrackingState, didExpire: Bool) {
        switch self {
        case .waitingForActivation:
            return (isActive ? .active : .waitingForActivation, false)

        case .active:
            if isActive {
                return (.active, false)
            } else {
                let next: ExperienceBuffTrackingState = missingFrameThreshold <= 1
                    ? .alertedInactive
                    : .confirmingInactive(count: 1)
                return (next, missingFrameThreshold <= 1)
            }

        case .confirmingInactive(let count):
            if isActive {
                // 잠깐 사라졌다가 다시 감지됨 → 오탐으로 간주, 복귀
                return (.active, false)
            }
            let nextCount = count + 1
            if nextCount >= missingFrameThreshold {
                return (.alertedInactive, true)
            } else {
                return (.confirmingInactive(count: nextCount), false)
            }

        case .alertedInactive:
            // 버프가 다시 켜지면 active로 전환, 아직 꺼져있으면 알림 없이 대기
            return (isActive ? .active : .alertedInactive, false)
        }
    }
}
