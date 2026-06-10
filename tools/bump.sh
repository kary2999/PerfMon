#!/bin/bash
# 自动递增版本号（语义化 X.Y.Z）并打 tag。
# 用法：tools/bump.sh [patch|minor|major]   默认 patch（小版本）
#   patch 1.2.0 -> 1.2.1   （bug 修复 / 小迭代）
#   minor 1.2.0 -> 1.3.0   （新功能）
#   major 1.2.0 -> 2.0.0   （重大变更）
# 打完 tag 后按提示 push，CI 会自动编译/测试/打包/发布 Release。
set -euo pipefail
cd "$(dirname "$0")/.."

FILE="Sources/PerfMonApp/AppInfo.swift"
LEVEL="${1:-patch}"

CUR=$(grep -oE 'version = "[^"]+"' "$FILE" | sed -E 's/.*"([^"]+)".*/\1/')
IFS='.' read -r MA MI PA <<< "$CUR"
MA=${MA:-0}; MI=${MI:-0}; PA=${PA:-0}

case "$LEVEL" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *) echo "用法: tools/bump.sh [major|minor|patch]"; exit 1 ;;
esac
NEW="$MA.$MI.$PA"

sed -i '' "s/version = \"$CUR\"/version = \"$NEW\"/" "$FILE"
git add "$FILE"
git commit -m "chore: bump version $CUR -> $NEW"
git tag "v$NEW" -m "PerfMon v$NEW"

echo "✅ 版本 $CUR -> $NEW，已提交并打 tag v$NEW"
echo "👉 推送触发自动发布： git push origin main \"v$NEW\""
