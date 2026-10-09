#!/bin/sh
# 배포 전 게이트 — 여기서 실패하면 DeployBar 가 아카이브를 만들지 않는다.
#
# 테스트 타깃이 아직 없어 Release 빌드가 되는지만 본다. 테스트를 만들면 `xcodebuild test` 로 바꾼다.
# LectureQ.xcodeproj 는 커밋하지 않으므로(.gitignore) project.yml 에서 먼저 만든다.
#
# ⚠️ CODE_SIGNING_ALLOWED=NO 로 빠르게 만들지 말 것 — entitlements(샌드박스)가 빠진 빌드는 배포 경로를 대변하지 못한다.
set -e
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

xcodegen generate >/dev/null

echo "🔨 Release 빌드 (LectureQ)"
xcodebuild build \
  -project LectureQ.xcodeproj \
  -scheme LectureQ \
  -configuration Release \
  -destination 'platform=macOS' \
  -quiet

echo ""
echo "✅ 게이트 통과 — 배포 가능"
