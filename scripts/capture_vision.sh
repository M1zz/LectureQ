#!/bin/zsh
# Apple Vision Pro 스토어 스크린샷 — 언어마다 시뮬레이터로 찍어 docs/screenshots/marketing/<언어>/vision-NN-*.jpg 에 둔다.
# 시뮬레이터가 뱉는 3840×2160 이 그대로 제출 규격이라 합성하지 않는다(창이 방 안에 뜬 모습 그대로).
# PNG 는 한 장에 수 MB 라 JPEG(품질 92)로 둔다 — 방 장면이라 차이가 보이지 않고 레포가 가볍다.
#
# 사용법:
#   zsh scripts/capture_vision.sh <Vision Pro 시뮬레이터 UDID> [언어 ...]     (언어를 안 주면 24개 모두)
#   - Debug 빌드가 build/dd/Build/Products/Debug-xrsimulator/LectureQ.app 에 있어야 한다(데모 모드는 DEBUG 전용).
#   - 장면은 iPad 와 같다(→ LectureQ/DemoData.swift 의 DemoScreen): main · capture · summary · graph
set -u
cd "$(dirname "$0")/.."

DEV=$1; shift
APP=build/dd/Build/Products/Debug-xrsimulator/LectureQ.app
BUNDLE=com.lectureq.LectureQ
ALL=(ko en en-GB zh-Hans zh-Hant ja ru es de fr it pt-BR th vi cs da el fi id nb nl pl sv tr)
if (( $# )); then LANGS=($@); else LANGS=($ALL); fi
SCENES=(main capture summary graph)

t() { perl -e 'alarm shift; exec @ARGV' "$@"; }

locale_of() {
  case $1 in
    ko) echo ko_KR ;; en) echo en_US ;; en-GB) echo en_GB ;; zh-Hans) echo zh_CN ;; zh-Hant) echo zh_TW ;;
    ja) echo ja_JP ;; ru) echo ru_RU ;; es) echo es_ES ;; de) echo de_DE ;; fr) echo fr_FR ;; it) echo it_IT ;;
    pt-BR) echo pt_BR ;; th) echo th_TH ;; vi) echo vi_VN ;; cs) echo cs_CZ ;; da) echo da_DK ;; el) echo el_GR ;;
    fi) echo fi_FI ;; id) echo id_ID ;; nb) echo nb_NO ;; nl) echo nl_NL ;; pl) echo pl_PL ;; sv) echo sv_SE ;;
    tr) echo tr_TR ;; *) echo en_US ;;
  esac
}

t 120 xcrun simctl boot $DEV 2>/dev/null
t 300 xcrun simctl bootstatus $DEV -b >/dev/null
t 300 xcrun simctl install $DEV $APP || { echo "설치 실패"; exit 1; }
# 부팅 뒤 첫 실행은 시뮬레이터가 Apple 계정 창을 띄운다. 한 번 띄웠다 끄면 그 뒤로는 뜨지 않는다.
t 60 xcrun simctl launch --terminate-running-process $DEV $BUNDLE -DemoMode YES -DemoScreen main >/dev/null 2>&1
sleep 10

for lang in $LANGS; do
  echo "▸ $lang"
  out=docs/screenshots/marketing/$lang; mkdir -p $out
  n=0
  for scene in $SCENES; do
    n=$((n+1))
    file=$out/vision-0$n-$scene.jpg
    for try in 1 2 3; do
      t 180 xcrun simctl launch --terminate-running-process $DEV $BUNDLE \
        -DemoMode YES -DemoScreen $scene -AppleLanguages "($lang)" -AppleLocale $(locale_of $lang) >/dev/null 2>&1 || continue
      sleep 8
      tmp=${TMPDIR:-/tmp}/lq-vision-$$.png
      t 90 xcrun simctl io $DEV screenshot $tmp >/dev/null 2>&1 || continue
      python3 -c "import sys;from PIL import Image;Image.open(sys.argv[1]).convert('RGB').save(sys.argv[2],quality=92,optimize=True)" $tmp $file && rm -f $tmp && break
    done
    [[ -f $file ]] && echo "  $file" || echo "  ✗ $file"
  done
done
