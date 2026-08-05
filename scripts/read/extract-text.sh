#!/usr/bin/env bash
# 판독 3단 사다리: pdftotext -layout → (부족시) pdftoppm 200dpi → (부족시) 400/900dpi.
# 텍스트 레이어가 충분하면 pagetext/raw.txt(폼피드 구분)를 만들고 끝낸다.
# 텍스트가 부족하면(쪽당 30자 미만) 렌더링 이미지만 만들어 두고, 그 다음은
# 사람/에이전트가 Read 도구로 직접 육안 판독해야 한다(자동화 불가 — README 참고).
#
# 사용법: extract-text.sh <pdf_path> <out_dir>
set -euo pipefail

PDF="${1:?pdf 경로 필요}"
OUT_DIR="${2:?출력 디렉터리 필요}"
mkdir -p "$OUT_DIR"

PAGES="$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2}')"
echo "[정보] 총 쪽수: ${PAGES:-알수없음}" >&2

pdftotext -layout "$PDF" "$OUT_DIR/raw.txt" 2>/dev/null || true

CHARS="$(wc -c < "$OUT_DIR/raw.txt" 2>/dev/null || echo 0)"
PER_PAGE=0
if [[ -n "${PAGES:-}" && "$PAGES" -gt 0 ]]; then
  PER_PAGE=$(( CHARS / PAGES ))
fi

echo "[정보] 추출 글자수=${CHARS}, 쪽당 평균=${PER_PAGE}자" >&2

if [[ "$PER_PAGE" -ge 30 ]]; then
  echo "[판정] 글자추출 충분 — $OUT_DIR/raw.txt 를 split-pages.sh 로 분리하십시오." >&2
  echo "글자추출"
  exit 0
fi

echo "[판정] 글자추출 부족(쪽당 ${PER_PAGE}자 < 30자) — 이미지 렌더링으로 전환합니다." >&2
IMG_DIR="$OUT_DIR/img"
mkdir -p "$IMG_DIR"
pdftoppm -r 200 -png "$PDF" "$IMG_DIR/p"

# 200dpi 렌더 이미지가 지나치게 작으면(육안 판독 곤란) 400dpi로 재시도
SMALL_COUNT=0
for f in "$IMG_DIR"/p-*.png; do
  [[ -f "$f" ]] || continue
  SIZE_KB=$(( $(wc -c < "$f") / 1024 ))
  if [[ "$SIZE_KB" -lt 30 ]]; then
    SMALL_COUNT=$((SMALL_COUNT+1))
  fi
done
if [[ "$SMALL_COUNT" -gt 0 ]]; then
  echo "[정보] 저해상 의심 쪽 ${SMALL_COUNT}건 — 400dpi 재렌더링(img400/)" >&2
  mkdir -p "$OUT_DIR/img400"
  pdftoppm -r 400 -png "$PDF" "$OUT_DIR/img400/p"
fi

echo "[다음 단계] $IMG_DIR (또는 img400/) 의 이미지를 Read 도구로 직접 판독한 뒤," >&2
echo "           결과를 $OUT_DIR/page01.txt, page02.txt ... 형식으로 직접 저장하고 gen-page-text-sql.sh 로 넘어가십시오." >&2
echo "이미지육안"
