#!/bin/zsh
# iPhone · iPad 스토어 스크린샷 — 꾸미지 않은 화면 그대로 docs/screenshots/marketing/<언어>/ 에 둔다.
# (Mac 그림 01_main.png … 과 한 폴더. DeployBar 가 크기로 기기를 가른다: 1320×2868 iPhone 6.9", 2064×2752 iPad 13")
#
# 사용법:
#   zsh scripts/capture_ios.sh <iphone|ipad> <시뮬레이터 UDID> [언어 ...]     (언어를 안 주면 24개 모두)
#   - Debug 빌드가 build/dd/Build/Products/Debug-iphonesimulator/LectureQ.app 에 있어야 한다(데모 모드는 DEBUG 전용).
#   - ONLY="main capture" 처럼 주면 그 장면만 다시 찍는다(번호는 그대로).
#   - 시뮬레이터는 한 번에 하나만 켠다. 이 스크립트가 켜고, 끝나면 끄지 않는다.
#
# 장면(→ LectureQ/DemoData.swift 의 DemoScreen):
#   iPhone: list(질문 목록) · main(질문과 답) · memo(타임블록 메모) · capture(질문 적기) · summary(요약)
#   iPad:   main(세 칸) · capture · summary · graph
set -u
cd "$(dirname "$0")/.."

KIND=$1; DEV=$2; shift 2
APP=build/dd/Build/Products/Debug-iphonesimulator/LectureQ.app
BUNDLE=com.lectureq.LectureQ
ALL=(ko en en-GB zh-Hans zh-Hant ja ru es de fr it pt-BR th vi cs da el fi id nb nl pl sv tr)
if (( $# )); then LANGS=($@); else LANGS=($ALL); fi

case $KIND in
  iphone) SCENES=(list main memo capture summary); PREFIX=iphone ;;
  ipad)   SCENES=(main capture summary graph);      PREFIX=ipad ;;
  *) echo "iphone 또는 ipad"; exit 1 ;;
esac

t() { perl -e 'alarm shift; exec @ARGV' "$@"; }   # 시뮬레이터가 멈추면 기다리지 않는다

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
t 60 xcrun simctl status_bar $DEV override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100 >/dev/null 2>&1
t 300 xcrun simctl install $DEV $APP || { echo "설치 실패"; exit 1; }

for lang in $LANGS; do
  echo "▸ $lang"
  out=docs/screenshots/marketing/$lang; mkdir -p $out
  loc=$(locale_of $lang)
  n=0
  for scene in $SCENES; do
    n=$((n+1))
    file=$out/$PREFIX-0$n-$scene.png
    [[ -n ${ONLY:-} && " $ONLY " != *" $scene "* ]] && continue
    for try in 1 2; do
      t 180 xcrun simctl launch --terminate-running-process $DEV $BUNDLE \
        -DemoMode YES -DemoScreen $scene -AppleLanguages "($lang)" -AppleLocale $loc >/dev/null 2>&1 || continue
      sleep 8
      # 시뮬레이터는 Documents 아래에 직접 못 쓸 때가 있다 → 임시 파일로 찍고 옮긴다
      tmp=${TMPDIR:-/tmp}/lq-shot-$$.png
      t 90 xcrun simctl io $DEV screenshot $tmp >/dev/null 2>&1 && mv -f $tmp $file && break
    done
    [[ -f $file ]] && echo "  $file" || echo "  ✗ $file"
  done
done
