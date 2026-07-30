#!/usr/bin/env bash
# 반입 누락 방지 문지기 (v2) — 대화가 열릴 때 업로드된 실물 파일을 전부 노출한다.
#
# v1의 결함 4건을 고쳤다 (2026-07-30 감사 지적):
#  ① `ls -dt | head -1` 로 최신 폴더 하나만 봐서, 새 대화에서 파일을 올리면
#     이전 대화의 미판독 파일이 시야에서 영구히 사라졌다 → 전 세대 일괄 스캔.
#  ② 경로 부재·권한 실패를 "폴더 비어 있음"으로 단정했다. 누락 방지 장치가
#     누락을 은폐하는 방향으로 고장났다 → "확인 불가"와 "파일 없음"을 구분한다.
#  ③ 크기순(-S) + head -40 이라 41건 넘으면 가장 작은 파일이 조용히 잘렸다.
#     최소 파일이 안내문.txt 류(대통령 지시가 담기는 유형)였다 → 도착순 + 생략 명시.
#  ④ 해시 접두를 sed로 지워 표시했더니 그 이름으로는 파일을 열 수 없었다
#     → 실물 경로를 그대로 출력한다.
# 또한 대장과 기계 대조가 가능하도록 지문(SHA256)과 붙여 쓸 조회문을 함께 낸다.
#
# 읽기 전용. 파일을 지우거나 바꾸지 않는다. 항상 exit 0 (세션을 막지 않는다).

ROOT=/root/.claude/uploads
MAX=60
STAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "[반입 점검 v2 · ${STAMP}]"   # 이 줄이 없으면 문지기가 돌지 않았다는 뜻이다.

if [ ! -d "$ROOT" ]; then
  echo "  ⚠️ 업로드 경로를 찾을 수 없음: $ROOT"
  echo "  → 이것은 '파일 없음'이 아니라 '확인 불가'다. 파일이 있는지 알 수 없다."
  echo "  → 대통령이 파일을 올렸다고 하면 경로를 직접 물어 확인할 것."
  exit 0
fi

if [ ! -r "$ROOT" ]; then
  echo "  ⚠️ 업로드 경로를 읽을 권한이 없음: $ROOT"
  echo "  → '파일 없음'이 아니라 '확인 불가'다."
  exit 0
fi

# 전 세대 폴더를 통째로 훑는다(도착 시각 오래된 것부터 — 오래 방치된 것이 위험하다).
mapfile -t FILES < <(find "$ROOT" -mindepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null \
                     | sort -n | cut -f2-)
N=${#FILES[@]}
DIRS=$(find "$ROOT" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

if [ "$N" -eq 0 ]; then
  echo "  업로드 폴더 비어 있음 (폴더 ${DIRS}개 확인, 파일 0건)."
  exit 0
fi

echo "  업로드 실물 ${N}건 (폴더 ${DIRS}개 전 세대 스캔):"

i=0
SHOWN=0
declare -a HASHES
for f in "${FILES[@]}"; do
  i=$((i+1))
  h=$(sha256sum "$f" 2>/dev/null | cut -c1-16)
  [ -n "$h" ] && HASHES+=("$h")
  if [ "$i" -le "$MAX" ]; then
    sz=$(stat -c%s "$f" 2>/dev/null)
    printf '  · %s  [%s bytes · 지문 %s]\n' "$f" "${sz:-?}" "${h:-계산실패}"
    SHOWN=$((SHOWN+1))
  fi
done

if [ "$N" -gt "$SHOWN" ]; then
  echo "  ⚠️ 위는 ${SHOWN}건만 표시 — 외 $((N-SHOWN))건 생략 (총 ${N}건). 생략분도 판독 대상이다."
fi

# 대장과 대조할 조회문을 완성해서 낸다. "조회하라"는 부탁만 남기면 건너뛰게 된다.
if [ "${#HASHES[@]}" -gt 0 ]; then
  list=$(printf "'%s'," "${HASHES[@]}"); list=${list%,}
  echo "  → 대장 대조 (그대로 실행할 것. 결과에 없는 지문 = 미등재 = 즉시 등재 대상):"
  echo "     select left(sha256,16) as 지문, 원본파일명, 상태, 판독요지 from public.intake"
  echo "     where left(sha256,16) in (${list});"
fi
echo "  → 현황: select * from public.v_intake_status;  (미판독·기록미판독·기한임박)"
echo "  ※ 파일명·크기로 무관 여부를 정하지 말 것. 전건 열어본 뒤에만 판정한다."
exit 0
