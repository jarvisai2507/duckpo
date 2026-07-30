#!/usr/bin/env bash
# 대화 중간 업로드 감지 (v1) — 대통령이 대화 도중 파일을 드래그하면 알린다.
#
# SessionStart 훅은 대화가 열릴 때 한 번만 돈다. 그래서 대화 중간에 올린 파일은
# 감지 수단이 0이었다 — 2026-07-29 사고(대통령이 올린 상담용 5종을 판독 대상에서
# 누락)가 정확히 이 경로였다. 매 프롬프트마다 증분만 확인해 그 구멍을 막는다.
#
# 새 파일이 없으면 아무것도 출력하지 않는다(토큰 절약). 읽기 전용, 항상 exit 0.

ROOT=/root/.claude/uploads
STATE=${CLAUDE_PROJECT_DIR:-/tmp}/.claude/.upload-seen

[ -d "$ROOT" ] && [ -r "$ROOT" ] || exit 0

mkdir -p "$(dirname "$STATE")" 2>/dev/null
touch "$STATE" 2>/dev/null

# 현재 실물 목록
CUR=$(find "$ROOT" -mindepth 1 -type f -printf '%p\n' 2>/dev/null | sort)
[ -z "$CUR" ] && exit 0

# 직전 확인 이후 새로 나타난 것만
NEW=$(comm -23 <(printf '%s\n' "$CUR") <(sort "$STATE" 2>/dev/null))
printf '%s\n' "$CUR" > "$STATE" 2>/dev/null

[ -z "$NEW" ] && exit 0

n=$(printf '%s\n' "$NEW" | grep -c .)
echo "[반입 점검 · 대화 중 새 파일 ${n}건 감지]"
printf '%s\n' "$NEW" | while read -r f; do
  [ -n "$f" ] || continue
  sz=$(stat -c%s "$f" 2>/dev/null)
  h=$(sha256sum "$f" 2>/dev/null | cut -c1-16)
  printf '  · %s  [%s bytes · 지문 %s]\n' "$f" "${sz:-?}" "${h:-계산실패}"
done
echo "  → 판독 전에 먼저 public.intake 에 등재할 것. 이 응답 안에서 등재하고 판독한다."
echo "  ※ 파일명·크기로 무관 여부를 정하지 말 것. 전건 열어본 뒤에만 판정한다."
exit 0
