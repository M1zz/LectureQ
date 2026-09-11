# 질문 노트 (LectureQ)

강의를 들으며 떠오른 질문을 쉬운 말로 바로 남기고, 시간 블록 메모·꼬리질문·AI 프롬프트로 답을 찾아 **배운 점**으로 정리하는 macOS 앱입니다.

## 링크

| 페이지 | 주소 |
|---|---|
| 홈 | https://m1zz.github.io/LectureQ/ |
| 지원 (Support) | https://m1zz.github.io/LectureQ/support.html |
| 개인정보 처리방침 (Privacy Policy) | https://m1zz.github.io/LectureQ/privacy.html |
| AI로 답 찾기 가이드 | https://m1zz.github.io/LectureQ/ai-guide.html |

## 핵심 기능

- **빠른 질문 (⌘⇧N)**: 툴바의 파란 *질문 추가* 버튼이나 단축키로 입력 시트를 띄웁니다. 시점(`HH:mm`)은 지금 시각으로 자동 입력되고, Return 저장 · ⌘Return 저장 후 계속 · Esc 취소.
- **질문 목록**: 왼쪽 목록에 원질문 → 꼬리질문(들여쓰기) 순서로 쌓입니다. 주황 빈 `?` = 미해결, 초록 꽉 찬 `?` = 해결, 눌러서 전환. 툴바 *미해결만*으로 필터.
- **타임블록 메모**: 강의 하나에 여러 시간 블록을 두고 블록마다 메모합니다. 질문은 시점에 맞춰 블록 세로 줄에 `?`로 표시되고(색 = 해결 여부, 채움 = 답 있음), 누르면 그 질문으로 이동합니다. 블록 밖 시각의 질문이 생기면 블록이 자동으로 추가되고, *설정*에서 색·시작·기간을 바꾸거나 삭제합니다.
- **질문 상세**: 해결됨 / 배운 점에 포함, 시점, 답, 원질문, 꼬리질문 추가·기존 질문 연결·해제.
- **AI 프롬프트 복사**: 질문 다듬기 → 답 찾기 → 답 되묻기 → 꼬리질문 뽑기 → 내 답 채점받기. 강의 이름·그 시점 메모·학습 상태·원질문을 채운 프롬프트를 클립보드로 복사합니다(앱은 외부와 통신하지 않음).
- **보기 메뉴**: 요약(⌘1) · 그래프(⌘2, 트리 레이아웃·줌·노드에서 질문으로 이동) · 타임블록 모아보기(⌘3) · 학습 상태(⌘4) · 글씨 크기(⌘+ / ⌘- / ⌘0).
- **대화 마크다운 가져오기**: `# 제목` → 강의, `## 섹션` → 원질문/꼬리질문 묶음, `**화자** — 내용` → 첫 화자의 발화는 질문, 다른 화자의 발화는 그 질문의 답.

## 실행 방법

이 저장소는 [XcodeGen](https://github.com/yonaskolb/XcodeGen)의 `project.yml`로 Xcode 프로젝트를 생성해 빌드/실행합니다.

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
- 프로젝트 설정(번들 ID, 배포 타겟, 앱 표시 이름, 엔타이틀먼트)은 모두 `project.yml`에 정의되어 있습니다.

## 데모 모드 · 앱스토어 스크린샷

Debug 빌드는 실행 인자로 데모 모드를 켤 수 있습니다. 실제 저장 파일 대신 메모리 저장소에 예시 강의·질문을 채우므로 내 데이터는 건드리지 않습니다.

```bash
open -n build/Build/Products/Debug/LectureQ.app --args -DemoMode YES -DemoScreen main
# DemoScreen: main / capture / graph / summary / timeline / state
```

앱스토어 스크린샷은 스크립트 한 번으로 만듭니다 (화면 기록 권한 필요, 결과: `appstore/screenshots/`).

```bash
appstore/capture.sh              # 전체
appstore/capture.sh graph state  # 일부 화면만
```

## 데이터 저장 위치

강의·블록·질문은 아래 **실제 파일**에 영속 저장됩니다.

```
~/Library/Containers/com.lectureq.LectureQ/Data/Library/Application Support/LectureQ/LectureQ.store
```

- `LectureQ.store` (본 데이터, SQLite) + `-wal`, `-shm` (SQLite 부속 파일)
- 백업: 앱을 종료한 뒤 위 폴더를 통째로 복사합니다.
- 초기화: 앱을 종료한 뒤 위 폴더를 삭제합니다. 앱을 휴지통에 버리는 것만으로는 이 폴더가 지워지지 않습니다.

## 파일 구성

| 파일 | 역할 |
|---|---|
| `LectureQApp.swift` | 앱 엔트리, ModelContainer (저장 파일 경로 고정, 데모 모드면 메모리 저장소) |
| `Models.swift` | `Lecture`, `Block`, `Question` SwiftData 모델 (꼬리질문 자기참조 포함) |
| `ContentView.swift` | 3단 레이아웃(질문 목록 / 강의 제목·타임블록 / 질문 상세), 툴바·보기 메뉴, 블록 자동 생성, 글씨 배율 |
| `QuickCaptureView.swift` | ⌘⇧N 질문 추가 시트 |
| `QuestionDetailView.swift` | 해결·배운 점·시점·답·AI 프롬프트 복사·꼬리질문 |
| `TimelineView.swift` | 블록 카드와 `?` 표시(`BlockView`), 타임블록 모아보기 시트, 시각 파싱 헬퍼 |
| `GraphView.swift` | 트리 레이아웃 질문 그래프 (줌, 노드에서 질문으로 이동) |
| `LectureSummaryView.swift` | 강의 요약 (던질 질문 · 배운 점 · 메모) |
| `LectureStateView.swift` | 학습 상태 (지금 · 목표 · 배우고 싶은 것) |
| `AIPrompts.swift` | AI로 답 찾기 5단계 프롬프트 생성 |
| `MarkdownImport.swift` | 대화 마크다운 → 강의 임포터 |
| `DemoData.swift` | 데모 모드 예시 데이터 (Debug 전용) |
| `docs/` | GitHub Pages (홈 · 지원 · 개인정보 처리방침 · AI 가이드) |
| `appstore/` | 앱스토어 스크린샷 캡처·합성 스크립트와 결과물 |

## 확장 아이디어

- 메뉴바 익스트라로 전역 캡처 (앱이 백그라운드여도 질문 입력)
- 강의 오디오 녹음 시각과 시점 자동 동기화
- 미해결 질문 리마인더 (복습 주기 기반 — spaced repetition)
