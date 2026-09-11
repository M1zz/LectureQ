#!/bin/bash
# 앱스토어 스크린샷 생성: 데모 모드로 앱을 띄워 화면별 창을 캡처하고 2880×1800 이미지로 합성한다.
#
# usage: appstore/capture.sh [screen ...]   (기본: main capture summary graph timeline state)
# 결과: appstore/screenshots/NN_<screen>.png
#
# - Debug 빌드의 데모 모드(-DemoMode YES)는 메모리 저장소에 예시 데이터를 채우므로 실제 데이터는 건드리지 않는다.
# - 캡처 동안 앱 창이 잠깐씩 앞으로 나온다. screencapture 에 화면 기록 권한이 필요하다.
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
S="$ROOT/appstore"
APP="$ROOT/build/Build/Products/Debug/LectureQ.app"
RAW="$S/raw"
WIN_W=1280; WIN_H=880; FONT_INDEX=1
SCREENS=("$@")
[ ${#SCREENS[@]} -eq 0 ] && SCREENS=(main capture summary graph timeline state)

echo "▶ Debug 빌드"
xcodegen generate >/dev/null
xcodebuild -project LectureQ.xcodeproj -scheme LectureQ -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build build | tail -1

[ -x "$S/winlist" ] || swiftc -O "$S/winlist.swift" -o "$S/winlist"
mkdir -p "$RAW"

for SCREEN in "${SCREENS[@]}"; do
  echo "▶ 캡처: $SCREEN"
  open -n "$APP" --args -DemoMode YES -DemoScreen "$SCREEN" -fontScaleIndex "$FONT_INDEX" \
    -DemoWidth "$WIN_W" -DemoHeight "$WIN_H" -ApplePersistenceIgnoreState YES

  PID=""
  for i in $(seq 1 50); do
    PID=$(pgrep -f "$APP/Contents/MacOS/LectureQ" | head -1 || true)
    [ -n "$PID" ] && break
    sleep 0.2
  done
  [ -z "$PID" ] && { echo "앱이 실행되지 않았습니다"; exit 1; }
  sleep 3.5   # 창 크기 조정 + 시트 표시 대기

  # 맨 앞 창(시트가 있으면 시트 — 부모 창과 합성되어 찍힘)만 캡처
  FRONT=$("$S/winlist" "$PID" | awk '$6 == 0 {print $1; exit}')
  screencapture -x -o -l "$FRONT" "$RAW/$SCREEN.png"
  kill "$PID"
  sleep 0.5
done

echo "▶ 합성"
python3 "$S/compose.py" "$RAW" "$S/screenshots"
