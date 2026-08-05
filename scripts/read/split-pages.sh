#!/usr/bin/env bash
# pdftotext -layout 결과(폼피드 \f 구분)를 pageNN.txt 파일들로 분리한다.
# 사용법: split-pages.sh <raw.txt> <out_dir>
set -euo pipefail

RAW="${1:?raw.txt 경로 필요}"
OUT_DIR="${2:?출력 디렉터리 필요}"
mkdir -p "$OUT_DIR"

python3 - "$RAW" "$OUT_DIR" <<'PYEOF'
import sys

raw_path, out_dir = sys.argv[1], sys.argv[2]
with open(raw_path, encoding='utf-8', errors='replace') as f:
    content = f.read()

pages = content.split('\f')
if pages and pages[-1].strip() == '':
    pages = pages[:-1]

written = 0
for i, ptext in enumerate(pages, start=1):
    t = ptext.strip('\n')
    if len(t.strip()) < 5:
        continue
    with open(f"{out_dir}/page{i:02d}.txt", 'w', encoding='utf-8') as out:
        out.write(t)
    written += 1

print(f"[분리 완료] 총 {len(pages)}쪽 중 {written}쪽에 내용 있음 → {out_dir}/pageNN.txt", file=sys.stderr)
PYEOF
