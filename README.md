# LectureQ — 강의 질문 메모 맥앱

강의를 들으면서 궁금한 점을 최대한 쉬운 말로 빠르게 남기고, 나중에 답을 찾아 기록하며, 질문·강의·연결 관계를 그래프로 볼 수 있는 macOS 앱입니다.

**링크**: [지원 페이지](https://m1zz.github.io/LectureQ/support.html) · [개인정보 처리방침](https://m1zz.github.io/LectureQ/privacy.html)

## 핵심 기능

- **빠른 질문 캡처 (⌘⇧N)**: 강의를 듣다가 단축키 하나로 질문 입력 시트를 띄우고, Return으로 즉시 저장합니다. ⌘Return으로 저장 후 계속 입력할 수 있어 흐름이 끊기지 않습니다. 강의 시점(예: 12:34)도 선택적으로 남길 수 있습니다.
- **답 기록**: 각 질문마다 답/찾은 내용 영역이 있고, 해결/미해결 상태를 토글합니다. 목록에서 원형 버튼으로 바로 해결 처리할 수 있습니다.
- **질문 연결**: 같은 강의 안의 질문끼리 "관련 질문"으로 연결할 수 있습니다 (SwiftData 자기참조 다대다 관계).
- **관계 그래프**: 강의(파랑) — 질문(미해결 주황 / 해결 초록) — 질문 간 링크를 포스 다이렉티드 레이아웃으로 시각화합니다. 노드를 드래그해 재배치할 수 있고, 호버하면 전체 텍스트가 보입니다.
- **미해결 필터**: 툴바 토글로 미해결 질문만 모아 봅니다. 사이드바에는 강의별 미해결 개수 배지가 표시됩니다.

## 실행 방법

이 저장소는 [XcodeGen](https://github.com/yoneyama/XcodeGen)의 `project.yml`로 Xcode 프로젝트를 생성해 바로 빌드/실행할 수 있습니다.

### 가장 빠른 방법 (스크립트)

```bash
./run.sh
```

`LectureQ.xcodeproj`가 없으면 자동 생성 → 빌드 → 앱 실행까지 한 번에 처리합니다.

### 수동 실행

```bash
# 1. (최초 1회) xcodegen 설치
brew install xcodegen

# 2. Xcode 프로젝트 생성
xcodegen generate

# 3-a. 커맨드라인 빌드
xcodebuild -project LectureQ.xcodeproj -scheme LectureQ \
  -configuration Debug -destination 'platform=macOS' build

# 3-b. 또는 Xcode에서 열어 ⌘R
open LectureQ.xcodeproj
```

- **요구사항**: macOS 14.0 이상 (SwiftData 필요), Xcode 15+
- 프로젝트 설정(번들 ID, 배포 타겟, 소스 구성)은 모두 `project.yml`에 정의되어 있습니다.

## 데이터 저장 위치

강의·질문·메모는 아래 **실제 파일**에 영속 저장됩니다 (앱을 껐다 켜도 유지됩니다).

```
~/Library/Application Support/LectureQ/LectureQ.store
```

- `LectureQ.store` (본 데이터, SQLite) + `-wal`, `-shm` (SQLite 부속 파일)
- 백업하려면 위 폴더를 통째로 복사하면 됩니다.
- 데이터를 초기화하려면 위 폴더를 삭제한 뒤 앱을 다시 실행하세요.

## 파일 구성

| 파일 | 역할 |
|---|---|
| `LectureQApp.swift` | 앱 엔트리, ModelContainer 설정 |
| `Models.swift` | `Lecture`, `Question` SwiftData 모델 (자기참조 링크 포함) |
| `ContentView.swift` | 3단 분할 뷰 (강의 사이드바 / 질문 목록 / 상세) |
| `QuickCaptureView.swift` | ⌘⇧N 빠른 질문 입력 시트 |
| `QuestionDetailView.swift` | 답 작성, 해결 토글, 질문 연결 UI |
| `GraphView.swift` | 포스 다이렉티드 그래프 (시뮬레이션 + Canvas 렌더링) |

## 확장 아이디어

- 메뉴바 익스트라로 전역 캡처 (앱이 백그라운드여도 질문 입력)
- 강의 오디오 녹음 시각과 timeMark 자동 동기화
- 그래프에서 노드 클릭 → 해당 질문 상세로 이동
- 미해결 질문 리마인더 (복습 주기 기반 — spaced repetition)
