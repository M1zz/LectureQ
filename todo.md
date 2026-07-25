# LectureQ 작업 현황

## 완료
- [x] `project.yml` 작성 (xcodegen 스펙: 번들 ID, macOS 14 타겟, Info.plist 자동 생성)
- [x] `xcodegen generate`로 `LectureQ.xcodeproj` 생성
- [x] 빌드 에러 수정: `QuickCaptureView.swift`의 `.onSubmit(save)` → `.onSubmit { save() }`
- [x] `xcodebuild` 빌드 성공 및 `.app` 번들 생성 확인
- [x] `run.sh` (생성→빌드→실행 자동화 스크립트) 추가
- [x] `.gitignore` 추가, README 실행 방법 갱신

## 완료 (기능 추가)
- [x] `Lecture` 모델에 `notes` 필드 추가 (강의 내용 메모용, 자동 경량 마이그레이션)
- [x] 질문 목록 상단에 접이식 `TextEditor` 강의 메모 에디터(`LectureNotesEditor`) 추가
- [x] 질문 목록 하단에 눈에 띄는 "질문 추가" 버튼(⌘⇧N) 배치

## 완료 (데이터 영속화)
- [x] 명시적 `ModelConfiguration`로 저장 파일 경로 고정: `~/Library/Application Support/LectureQ/LectureQ.store`
- [x] 저장소 열기 실패 시 파일을 임의 삭제하지 않고 `fatalError`로 중단 → 데이터 유실 방지
- [x] 앱 실행 시 `.store`/`-wal`/`-shm` 파일 실제 생성 확인

## 완료 (꼬리질문 위계)
- [x] "관련 질문" → "꼬리질문"으로 명칭 변경
- [x] 상세 뷰: `allRelated`(방향 무시) → 원질문(상위)/현재/꼬리질문(하위) 트리로 표시
- [x] 부모(원질문, 보라 "원질문" 배지)와 자식(꼬리, 청록 "꼬리" 배지)을 들여쓰기·아이콘·색으로 구분
- [x] 그래프: 질문-질문 엣지를 방향성 화살표(원질문 → 꼬리질문, 청록)로 렌더링 + 범례 추가
- [x] 질문 목록도 트리로 표시: 원질문 아래 꼬리질문을 들여쓰기(depth×18) + ↳ 아이콘 + 청록 "꼬리" 배지 (`orderedHierarchy` DFS)

## 완료 (앱 로고 + 상태 복원)
- [x] Pillow로 앱 로고 생성 (파랑→청록 그라데이션 + 흰 말풍선 + 물음표 + 청록/주황 노드)
- [x] `Assets.xcassets/AppIcon.appiconset` 구성(16~1024, @1x/@2x) + `project.yml`에 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
- [x] 빌드 후 번들에 `AppIcon.icns` 포함 확인
- [x] `@AppStorage("lastLectureUUID")`로 마지막 본 강의 기억 → 다음 실행 때 복원, 없으면 최상단(최신) 강의 자동 선택

## 완료 (강의 요약 화면)
- [x] `LectureSummaryView` 추가: 통계 타일(전체/던질질문/배운점/꼬리질문) + 강의 메모 + 던질 질문(미해결) + 배운 점(해결+답)
- [x] 툴바 "요약" 버튼(강의 선택 시 활성)으로 시트 오픈

## 완료 (그래프 트리 레이아웃)
- [x] 포스 다이렉티드 시뮬레이션 제거 → 위→아래 트리 레이아웃(`layoutTree`)
- [x] 강의=루트(맨 위) → 최상위 질문 → 꼬리질문 순으로 깊이별 배치, 부모 x = 자식 중앙
- [x] 여러 강의는 나란히 놓인 forest, 전체를 캔버스 가로 중앙 정렬 + 창 리사이즈 시 재배치
- [x] 노드 드래그는 유지(물리 없이 위치만 이동)

## 완료 (강의 타임블록)
- [x] `Lecture`에 `startTime`, `durationMinutes` 추가(기본값 포함, 기존 데이터 경량 마이그레이션 확인)
- [x] `TimelineView`: 강의를 소요시간 비례 높이의 타임블록으로 세로 배치, 왼쪽 시간 게이지
- [x] 블록 안에서 제목/시작시각(DatePicker)/소요시간(메뉴)/메모(TextEditor) 직접 편집, uuid 기반 강의별 색
- [x] 툴바 "타임블록" 버튼으로 시트 오픈, 실행 시 마이그레이션 크래시 없음 확인

## 완료 (타임블록 배치·관계·추가)
- [x] 타임블록을 강의 메모 자리(가운데 열 상단)로 이동 — `LectureNotesEditor` 제거, `LectureTimeBlock` 임베드
- [x] 그래프: 꼬리질문은 강의와 직접 연결 끊고 원질문(부모)에만 연결 (최상위 질문만 강의에 연결)
- [x] 타임블록에 "블록 추가" 버튼 + 빈 상태 액션 버튼
- [x] 새 블록은 시작 시각을 지금 시각(.now)과 동기화 → 정렬상 맨 마지막 블록이 현재 시각

## 완료 (꼬리질문 직접 생성 + 타임블록 UX)
- [x] 타임블록: 마지막 블록 아래 점선 "블록 추가" 버튼, 메모 칸 확대(블록 하한 260, 메모 minHeight 150)
- [x] 상세 뷰: 새 꼬리질문을 직접 입력해 만드는 입력창(`addFollowUp`) 추가 — 기존 질문 연결 메뉴는 "기존 질문을 꼬리질문으로 연결"로 유지

## 완료 (레이아웃 재구성 — 질문 리스트 분리)
- [x] 사이드바를 VSplitView로: 위=강의 목록, 아래=질문 리스트(위계) + "질문 추가"
- [x] 가운데 열=타임블록/메모 전용(`fillsHeight`로 열 높이 가득 채움)
- [x] 오른쪽=질문 상세 그대로. 실행 확인 완료

## 완료 (강의 선택 숨김 + 블록 추가 + 그래프 구분)
- [x] 사이드바에서 강의 목록 제거 → 툴바 강의 메뉴(Picker+추가+삭제)로 숨김, 사이드바는 질문 리스트만
- [x] 메인 툴바에 "블록 추가"(지금 시각) 버튼 → 추가 즉시 선택되어 메인에 표시
- [x] 그래프: 답 내용 있는 질문=꽉 찬 원 / 질문만(답 없음)=빈 원(테두리), 범례 추가

## 완료 (타임블록 수직 라인에 질문 표시 + 추가 버튼 정리)
- [x] 메모 열 블록 하단 점선 "블록 추가" 버튼(추가 즉시 선택)
- [x] 툴바 상시 "블록 추가" 버튼 제거(강의 메뉴 안 "강의 추가" + 메모 열 버튼으로만)
- [x] 타임블록 수직 라인에 질문 점 표시: timeMark(mm:ss/hh:mm:ss) 있으면 시점 비율 위치, 없으면 순서 균등 / 색=해결여부, 채움=답 유무 / hover 툴팁

## 완료 (강의 1개 = 시간 블록 여러 개)
- [x] `Block` 모델 추가(startTime/duration/notes), `Lecture 1—N Block` 관계, 스키마 등록, 마이그레이션 확인
- [x] 레거시 Lecture.notes/startTime/duration 보존 + 최초 선택 시 초기 블록으로 시딩(`ensureBlocks`)
- [x] 메모 열: 강의 제목(편집) + 강의의 블록들 세로 스택 + "블록 추가"(현재 강의에 블록 아래 추가)
- [x] `LectureTimeBlock` → `BlockView(block:)`, 질문 마커는 블록들 누적 시간축에 매핑(`computeBlockMarkers`)
- [x] 타임블록 시트: 모든 강의의 블록을 시간순으로 표시(강의명 라벨)
- [x] 요약: 블록 메모 합쳐 표시
- [x] 질문 추가 버튼을 마지막 질문 아래 인라인으로 이동

## 완료 (질문 점 클릭 이동 + 블록 자동 확장)
- [x] 타임라인 질문 점을 버튼화 → 클릭 시 해당 질문 상세로 이동(`onSelectQuestion`), 클릭 영역 확대
- [x] 질문 timeMark가 블록 총길이를 벗어나면 마지막 블록 뒤에 커버 블록 자동 추가(`ensureCoverage` + `coverageSignature` onChange)

## 완료 (Q 버튼 + 시각 기반 위치 + 닫기 버튼)
- [x] 질문 마커를 눌리는 Q 버튼으로(호버 확대/누름 축소 `QDotButtonStyle`, 그림자·테두리)
- [x] timeMark를 벽시계 시각으로 해석 → 블록 실제 [start,end] 범위에 매핑(예 9:10~12:10 블록에 12:00이면 끝자락). `parseClock`/`clockDate`
- [x] 커버리지도 시각 기반: 마지막 블록 종료 시각을 넘는 질문이면 그만큼 블록 자동 추가
- [x] 질문 추가(QuickCapture) 시트에 X 닫기 버튼(Esc)

## 완료 (Q 버튼 겹침 방지)
- [x] 가까운 시각의 Q 버튼이 겹치면 최소 간격(27pt)으로 밀어내 모두 표시(`laidOut` 1D declutter), 라인 범위 클램프

## 완료 (블록 밖 질문 → 블록 생성: 앞·사이·뒤 전부)
- [x] `ensureCoverage`가 첫 블록 앞 / 블록 사이 빈 시간 / 마지막 블록 뒤 세 경우 모두 커버 블록 생성
- [x] `coverageSignature`에 블록 구성 전체 포함 → 앞/사이 블록 추가도 재호출되어 여러 질문 순차 처리(수렴)

## 완료 (유효 시각 통일 — timeMark 없는 질문도 블록 생성)
- [x] 질문 유효 시각 = timeMark 있으면 그 시각, 없으면 작성시각(createdAt) (`questionTime` 공용 헬퍼)
- [x] `ensureCoverage`가 timeMark 없는 질문도 대상 → 밖이면 그 시각 담는 작은 블록(±30분, 이웃과 안 겹치게 클램프) 생성
- [x] 예: 9:10~12:10 블록에서 3:11 PM 작성 꼬리질문 → 2:41~3:41 블록 자동 생성되어 Q 버튼 이동

## 완료 (블록 색상 구분 + 변경)
- [x] `Block.colorHue`(음수=uuid 자동색) 추가, 마이그레이션 확인
- [x] 블록 헤더에 ColorPicker → 고른 색의 hue 저장(채도·명도는 앱 톤 통일), 배경 틴트 0.18로 강화

## 완료 (설정 "..." 메뉴 + 블록 기본 기간)
- [x] 색상·시작·기간 설정을 블록의 "..." 버튼 → 팝오버(`settingsPopover`)로 이동, 카드 헤더 간소화
- [x] 새 블록은 만든 시각에 시작; 추가 시 직전 블록 기간을 "지금까지"로 자동 설정(다음 블록 생성 전까지 이어짐)

## 완료 (플레이스홀더 정렬 + 글씨 크기)
- [x] 타임블록 메모 플레이스홀더를 TextEditor 텍스트 시작 위치(leading 5, top 0, 동일 폰트)에 맞춰 커서와 정렬
- [x] 툴바 − aA + 버튼으로 앱 글씨 크기 조절(`@AppStorage dynTypeIndex` + `.dynamicTypeSize`), 모든 시트에도 적용

## 완료 (강의별 학습 상태 메모)
- [x] `Lecture`에 currentState/goalState/wantToLearn 필드 추가(기본 "", 마이그레이션 확인)
- [x] `LectureStateView` 시트: 지금 상태·마쳤을 때 상태·배우고 싶은 것 3개 에디터
- [x] 툴바 "학습 상태" 버튼으로 열기(평소엔 숨김)

## 완료 (글씨 크기 실제 적용 — macOS)
- [x] macOS에서 dynamicTypeSize 미동작 → 직접 배율(`fontScale` 환경값 + `scaledFont` 모디파이어)로 전환
- [x] 툴바 − aA + 가 `fontScaleIndex`(0.85~2.0배) 조절, @AppStorage 저장
- [x] 주요 텍스트에 scaledFont 적용: 블록 메모/플레이스홀더, 질문 목록, 질문 상세(질문·답), 강의 제목, 학습상태 에디터

## 완료 (앱 전체 폰트 배율 적용)
- [x] 텍스트 스타일 기반 `scaledFont(_ style:)` 오버로드(.body/.caption/.headline 등 → 배율 pt 매핑)
- [x] 앱 전 파일의 `.font(...)` 호출을 `.scaledFont(...)`로 일괄 교체(모노스페이스·굵기·디자인 보존)
- [x] 남은 `.font(.system(size:))`는 배율 모디파이어 내부/aA 버튼/Q 마커 글리프뿐(의도적 고정)

## 완료 (배포 페이지 + 전역 글씨 크기 보강)
- [x] 퍼블릭 레포 github.com/M1zz/LectureQ 커밋·푸시
- [x] docs/ 지원·개인정보 처리방침·랜딩 페이지 + GitHub Pages(/docs) 활성화, 라이브 확인
  - 지원: https://m1zz.github.io/LectureQ/support.html
  - 개인정보: https://m1zz.github.io/LectureQ/privacy.html
- [x] 글씨 배율을 각 열/시트에 개별 적용 + 환경 기본 폰트도 배율화(appFontScale) → 앱 전체 텍스트 반영

## 다음 아이디어 (README 확장 아이디어 참고)
- [ ] 메뉴바 익스트라 전역 캡처
- [ ] 그래프 노드 클릭 → 질문 상세 이동
- [ ] 미해결 질문 spaced-repetition 리마인더
