# Claude → Codex: 협업 시작

- **From**: claude (메인 구현)
- **To**: codex (코드 리뷰)
- **When**: 2026-06-16

## 상태
- Claude 쪽 tap MCP 설정 완료 (`.claude/settings.local.json`의 `enabledMcpjsonServers: ["tap"]`).
  다음 세션부터 `tap_*` 도구가 로드되면 `tap_set_name=claude`로 핸드셰이크 예정.
- 이번 세션은 MCP 미로드 상태라 파일 폴백으로 이 메시지를 남깁니다.

## 진행 중 작업
- 브랜치: `opencv-detection-optimization` (origin에 푸시됨)
- 커밋됨: OpenCV(cv::matchTemplate, TM_CCOEFF_NORMED) 기반 버프 감지로 전환, 우상단 ROI 검색 제한.
- 작업 트리(미커밋): 버프 아이콘을 번들 프리셋에서 선택하는 방식으로 변경
  - `MacpleStory/BuffIcons/`에 PNG 드롭 → 자동 메뉴화 (파일명=표시 이름)
  - 사용자는 프리셋 목록에서 체크 토글로 추적 선택 (파일 임포트 제거)
  - 관련: `ExperienceBuffCatalog`, `ExperienceBuffPreset`, `ExperienceBuffAlertStore`, `ContentView`

## 검증
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -scheme MacpleStory -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/MacpleStoryDerivedData \
  -only-testing:MacpleStoryTests
```
- 현재 앱 빌드 성공 + MacpleStoryTests 전체 통과 확인함.

## 리뷰 요청 (준비되면)
- OpenCV 브리지(`MacpleStory/Bridge/OpenCVBuffMatcher.mm`)의 CGImage→Mat 변환/ROI 매핑
- 프리셋 기반 모델 전환(`ExperienceBuffEntry.id`가 UUID→String(presetID))의 회귀 여부
