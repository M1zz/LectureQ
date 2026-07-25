#!/bin/bash
# LectureQ 빌드 & 실행 스크립트
set -e
cd "$(dirname "$0")"

# 프로젝트 파일이 없으면 xcodegen으로 생성 (xcodegen 필요: brew install xcodegen)
if [ ! -d "LectureQ.xcodeproj" ]; then
  echo "▶ LectureQ.xcodeproj 생성 중..."
  xcodegen generate
fi

echo "▶ 빌드 중..."
xcodebuild -project LectureQ.xcodeproj -scheme LectureQ \
  -configuration Debug -destination 'platform=macOS' \
  build | tail -1

APP=$(xcodebuild -project LectureQ.xcodeproj -scheme LectureQ \
  -configuration Debug -showBuildSettings 2>/dev/null \
  | grep -m1 "BUILT_PRODUCTS_DIR" | sed 's/.*= //')/LectureQ.app

echo "▶ 실행: $APP"
open "$APP"
