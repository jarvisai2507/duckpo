#!/usr/bin/env bash
# 반입 누락 방지 — 대화가 열릴 때 업로드 폴더를 훑어 파일 목록을 노출한다.
# 파일명만 출력하므로 토큰이 거의 들지 않는다. (CLAUDE.md 「반입대장 강제 점검」)
d=$(ls -dt /root/.claude/uploads/*/ 2>/dev/null | head -1)
if [ -n "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
  n=$(ls -1 "$d" | wc -l | tr -d ' ')
  echo "[반입 점검] 업로드 폴더에 ${n}건 있음:"
  ls -1S "$d" | sed 's/^[0-9a-f]\{8\}-//' | head -40 | sed 's/^/  · /'
  echo "  → public.v_intake_status 를 조회해 미판독 건수를 확인하고, 미등재분은 즉시 intake 에 등재할 것."
else
  echo "[반입 점검] 업로드 폴더 비어 있음."
fi
