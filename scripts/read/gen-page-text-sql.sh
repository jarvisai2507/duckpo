#!/usr/bin/env bash
# pageNN.txt 파일들을 public.evidence_page_text INSERT문(달러 인용)으로 변환해 stdout에 출력.
# 그 출력을 Supabase MCP execute_sql로 그대로 실행하면 캐시에 들어간다.
#
# 사용법: gen-page-text-sql.sh <evidence_id> <판독방법: 글자추출|이미지육안|OCR> <page_dir> [캡처자]
set -euo pipefail

EVIDENCE_ID="${1:?evidence_id 필요 (case_evidence.id, 정수)}"
METHOD="${2:?판독방법 필요 (글자추출|이미지육안|OCR)}"
PAGE_DIR="${3:?page_dir 필요 (pageNN.txt 들이 있는 디렉터리)}"
CAPTURER="${4:-기록실장}"

case "$METHOD" in
  글자추출|이미지육안|OCR) ;;
  *) echo "오류: 판독방법은 글자추출|이미지육안|OCR 중 하나여야 합니다" >&2; exit 1 ;;
esac

python3 - "$EVIDENCE_ID" "$METHOD" "$PAGE_DIR" "$CAPTURER" <<'PYEOF'
import sys, glob, re, os

evidence_id, method, page_dir, capturer = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

files = sorted(glob.glob(os.path.join(page_dir, "page*.txt")))
if not files:
    print(f"-- 경고: {page_dir} 에 page*.txt 파일이 없습니다", file=sys.stderr)
    sys.exit(1)

values = []
for fp in files:
    m = re.search(r'page(\d+)\.txt$', fp)
    if not m:
        continue
    page_no = int(m.group(1))
    with open(fp, encoding='utf-8', errors='replace') as f:
        text = f.read().strip('\n')
    if len(text.strip()) < 5:
        continue
    safe = text.replace('$pgtxt$', '$ pgtxt $')
    values.append(f"  ({evidence_id}, {page_no}, '{method}', $pgtxt${safe}$pgtxt$, '{capturer}')")

if not values:
    print("-- 경고: 유효한 페이지 내용이 없습니다", file=sys.stderr)
    sys.exit(1)

print("insert into public.evidence_page_text (evidence_id, 쪽번호, 판독방법, 원문텍스트, 캡처자) values")
print(",\n".join(values))
print("on conflict (evidence_id, 쪽번호, 판독회차) do nothing;")
print(f"-- {len(values)}쪽 생성", file=sys.stderr)
PYEOF
