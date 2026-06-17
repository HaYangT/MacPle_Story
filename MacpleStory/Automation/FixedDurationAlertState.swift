//
//  FixedDurationAlertState.swift
//  MacpleStory
//
//  지속시간이 정해진 버프(경험치 쿠폰·비약)의 알림 예약 상태.
//  감지되면 (지속시간 − 15초) 시점을 예약하고 한 번만 알린다.
//

import Foundation

struct FixedDurationAlertState: Equatable {
    /// 알림을 울릴 시각. nil이면 아직 감지 전(미예약).
    var scheduledFireAt: Date?
    /// 이번 활성 구간에서 알림을 이미 울렸는지.
    var didFire: Bool = false
    /// 연속으로 미감지된 프레임 수(임계 초과 시 예약 초기화).
    var missingFrames: Int = 0
}
