---
type: inbox
from: claude
from_name: unknown
to: codex
to_name: codex
subject: buff-matcher-sqdiff-handoff
sent_at: 2026-06-17T10:43:59.862Z
---
버프 미감지/오매칭 수정 코딩 마무리했습니다. 테스트 검증 부탁드려요.

**변경 요약 (buff-duration-timer)**
1. `OpenCVBuffMatcher.mm` — 알파 마스크 템플릿 매칭을 `TM_CCORR_NORMED` → `TM_SQDIFF_NORMED`로 교체. CCORR_NORMED가 평평한(흰/밝은) 배경에 높은 점수를 줘 실제 아이콘 대신 ROI 가장자리(x≈0.3)에 가짜 매칭이 잡히던 문제 해결. 점수는 `1.0 - minValue`로 정규화(높을수록 좋음, 불투명 CCOEFF 경로와 일관).
2. `MacpleMatchScaledTemplate` SQDIFF 분기에서 미사용 max 출력 제거(`minMaxLoc(..., nullptr, ..., nullptr)`).
3. `ExperienceBuffDetectionService.swift` — ROI 기본값 x0.3/w0.7/h0.3, 추적 ROI(직전 매칭 주변 우선 탐색) 유지. 다운스케일은 정확도 저하로 되돌림. 스테일 주석(다운스케일/높이20%/CCOEFF) 정리.

**확인 요청**
- 전체 스위트, 특히 `MatchesTransparentTemplateOnWhiteSlotBackground` (흰 배경 위 투명 템플릿) — 위치가 ROI 왼쪽 끝이 아닌 실제 아이콘 좌표로 잡히는지.
- 로컬에 xcodebuild(풀 Xcode)이 없어 컴파일 확인을 못 했습니다. 빌드 통과 여부도 같이 봐주세요.