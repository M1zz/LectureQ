#!/bin/bash
# 앱스토어 스크린샷 생성: 데모 모드로 앱을 띄워 화면별 창을 캡처하고 2880×1800 이미지로 합성한다.
#
# usage: [LOCALE=en-GB] [SKIP_BUILD=1] appstore/capture.sh [screen ...]
#        (기본: LOCALE=ko, 화면 main capture summary graph timeline state)
# 결과: docs/screenshots/marketing/<LOCALE>/NN_<screen>.png (DeployBar 가 여기서 읽어 올린다)
#       원본 창 캡처는 docs/screenshots/raw/<LOCALE>/<screen>.png
#       데모 데이터(DemoText)와 헤드라인(appstore/captions.json)도 그 언어로 나온다.
#
# - Debug 빌드의 데모 모드(-DemoMode YES)는 메모리 저장소에 예시 데이터를 채우므로 실제 데이터는 건드리지 않는다.
# - 캡처 동안 앱 창이 잠깐씩 앞으로 나온다. screencapture 에 화면 기록 권한이 필요하다.
set -e
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
S="$ROOT/appstore"
APP="$ROOT/build/Build/Products/Debug/LectureQ.app"
LOCALE="${LOCALE:-ko}"
case "$LOCALE" in
  ko) REGION=ko_KR ;; en) REGION=en_US ;; en-GB) REGION=en_GB ;;
  zh-Hans) REGION=zh_CN ;; zh-Hant) REGION=zh_TW ;; ja) REGION=ja_JP ;;
  pt-BR) REGION=pt_BR ;; cs) REGION=cs_CZ ;; da) REGION=da_DK ;; el) REGION=el_GR ;;
  nb) REGION=nb_NO ;; sv) REGION=sv_SE ;; vi) REGION=vi_VN ;;
  *) REGION="${LOCALE}_$(echo "$LOCALE" | tr '[:lower:]' '[:upper:]')" ;;
esac
RAW="$ROOT/docs/screenshots/raw/$LOCALE"
OUT="$ROOT/docs/screenshots/marketing/$LOCALE"
WIN_W=1440; WIN_H=990; FONT_INDEX=1
SCREENS=("$@")
[ ${#SCREENS[@]} -eq 0 ] && SCREENS=(main capture summary graph timeline state)

if [ "${SKIP_BUILD:-0}" != 1 ]; then
  echo "▶ Debug 빌드"
  xcodegen generate >/dev/null
  xcodebuild -project LectureQ.xcodeproj -scheme LectureQ -configuration Debug \
    -destination 'platform=macOS' -derivedDataPath build build | tail -1
fi

[ -x "$S/winlist" ] || swiftc -O "$S/winlist.swift" -o "$S/winlist"
mkdir -p "$RAW"

for SCREEN in "${SCREENS[@]}"; do
  echo "▶ 캡처: $LOCALE $SCREEN"
  open -n "$APP" --args -DemoMode YES -DemoScreen "$SCREEN" -fontScaleIndex "$FONT_INDEX" \
    -DemoWidth "$WIN_W" -DemoHeight "$WIN_H" -ApplePersistenceIgnoreState YES \
    -AppleLanguages "($LOCALE)" -AppleLocale "$REGION"

  PID=""
  for i in $(seq 1 50); do
    # 경로로 찾지 않는다 — 한글 폴더 이름은 NFC/NFD 가 달라 pgrep -f 가 놓친다.
    PID=$(pgrep -nx LectureQ || true)
    [ -n "$PID" ] && break
    sleep 0.2
  done
  [ -z "$PID" ] && { echo "앱이 실행되지 않았습니다"; exit 1; }
  sleep 3.5   # 창 크기 조정 + 시트 표시 대기
  # 부하가 있으면 앱이 앞으로 못 나와 창이 비활성(회색 신호등·툴바)으로 찍힌다 — 한 번 더 앞으로 부른다.
  open "$APP"
  sleep 1.5

  # 맨 앞 창(시트가 있으면 시트 — 부모 창과 합성되어 찍힘)만 캡처
  FRONT=$("$S/winlist" "$PID" | awk '$6 == 0 {print $1; exit}')
  screencapture -x -o -l "$FRONT" "$RAW/$SCREEN.png"
  kill "$PID"
  sleep 0.5
done

echo "▶ 합성"
python3 "$S/compose.py" "$RAW" "$OUT" "$LOCALE"
