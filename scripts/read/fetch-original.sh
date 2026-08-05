#!/usr/bin/env bash
# 원본 파일 확보 — 캐시(manifest.tsv, sha256) 먼저 확인, 없을 때만 열람구(tmp_read_v2)에서 다운로드.
# 사용법: fetch-original.sh <storage_path> <evidence_no>
# 필요 환경변수: SCRATCH, FN_URL, FN_KEY
set -euo pipefail

STORAGE_PATH="${1:?storage_path 필요}"
EVIDENCE_NO="${2:?evidence_no 필요 (예: 증H-76)}"
: "${SCRATCH:?SCRATCH 환경변수 필요 (세션 스크래치패드 경로)}"

ORIG_DIR="$SCRATCH/originals"
MANIFEST="$ORIG_DIR/manifest.tsv"
mkdir -p "$ORIG_DIR"
touch "$MANIFEST"

SAFE_NAME="$(echo "$EVIDENCE_NO" | tr -d '증' | tr -cd '[:alnum:]-')"
OUT_PATH="$ORIG_DIR/${SAFE_NAME}.pdf"

# 1) 매니페스트에 이미 있으면 재사용 (파일도 실제로 있는지 확인)
EXISTING_LINE="$(grep -F -m1 "	${EVIDENCE_NO}	" "$MANIFEST" 2>/dev/null || true)"
if [[ -n "$EXISTING_LINE" ]]; then
  EXISTING_PATH="$(echo "$EXISTING_LINE" | cut -f3)"
  if [[ -f "$EXISTING_PATH" ]]; then
    echo "[캐시 재사용] $EVIDENCE_NO → $EXISTING_PATH (열람구 재개방 없음)" >&2
    echo "$EXISTING_PATH"
    exit 0
  fi
fi

# 2) 없으면 열람구에서 새로 받음
: "${FN_URL:?FN_URL 환경변수 필요 (tmp_read_v2 함수 URL)}"
: "${FN_KEY:?FN_KEY 환경변수 필요 (세션 내 임시 열쇠)}"

echo "[다운로드] $EVIDENCE_NO ← $STORAGE_PATH" >&2
SIGNED_JSON="$(curl -sS "${FN_URL}?path=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$STORAGE_PATH")" -H "x-key: ${FN_KEY}")"
SIGNED_URL="$(echo "$SIGNED_JSON" | python3 -c "import json,sys;print(json.load(sys.stdin)['signedUrl'])")"

curl -sSL "$SIGNED_URL" -o "$OUT_PATH"

SHA="$(sha256sum "$OUT_PATH" | cut -d' ' -f1)"
BYTES="$(wc -c < "$OUT_PATH")"

# 기존 동일 evidence_no 줄 제거 후 새로 기록
grep -vF "	${EVIDENCE_NO}	" "$MANIFEST" > "${MANIFEST}.tmp" 2>/dev/null || true
mv "${MANIFEST}.tmp" "$MANIFEST"
printf '%s\t%s\t%s\t%s\t%s\n' "$SHA" "$EVIDENCE_NO" "$OUT_PATH" "$BYTES" "$(date -u +%FT%TZ)" >> "$MANIFEST"

echo "[다운로드 완료] $EVIDENCE_NO → $OUT_PATH (sha256=${SHA:0:16}...)" >&2
echo "$OUT_PATH"
