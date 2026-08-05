# 판독 파이프라인 스크립트 (scripts/read/)

원본 문서를 열람구(edge function `tmp_read_v2`)에서 받아 텍스트를 뽑아내고,
`public.evidence_page_text` 캐시에 넣을 SQL을 생성하는 4단계 도구.
매번 즉석 Bash 명령을 새로 짜는 대신 이 스크립트를 재사용한다
(2026-08-05 신설 — 판독-감사 반복비효율 구조개선 계획 5단계).

## ⚠️ 반드시 지킬 것

- **원본 파일·다운로드 산출물·렌더링 이미지는 절대 git에 커밋하지 않는다.**
  전부 `$SCRATCH`(세션 스크래치패드) 아래에만 둔다 — `.gitignore`가 `scratchpad/`를 이미 제외하고 있다.
- 이 디렉터리(`scripts/read/`)에는 **코드만** 있다. 데이터는 여기 들어오지 않는다.
- `tmp_read_v2` 열람구는 평시 410(Gone)으로 봉쇄돼 있다. 사용 전 세션 내에서 임시 키로
  재배포하고, 판독이 끝나면 반드시 410 스텁으로 재봉쇄한다(CLAUDE.md "반입구 비밀열쇠는
  코드 세션 내에서 생성→사용→410 재봉쇄" 원칙).

## 캐시-먼저 원칙

`fetch-original.sh`는 다운로드 전에 **로컬 매니페스트(sha256)를 먼저 확인**한다.
이미 받아둔 파일이 있으면 열람구를 다시 열지 않고 그대로 재사용한다 —
2026-08-05 4차 감사에서 실제로 이 방식으로 열람구 재개방 없이 재검증을 마쳤다.

## 사용 순서

```bash
export SCRATCH=/tmp/claude-0/.../scratchpad   # 세션 스크래치패드 경로
export FN_URL="https://<project>.supabase.co/functions/v1/tmp_read_v2"
export FN_KEY="<세션 내에서 새로 발급한 임시 키>"

# 1) 원본 확보 (캐시에 있으면 재다운로드 안 함)
scripts/read/fetch-original.sh <storage_path> <evidence_no>

# 2) 텍스트 추출 (3단 사다리: pdftotext → pdftoppm 200dpi → 400/900dpi)
#    텍스트 레이어가 없거나 부실하면 이미지 렌더링까지만 하고 멈춘다 —
#    그 다음은 Read 도구로 직접 육안 판독해야 한다(자동화 불가 구간).
scripts/read/extract-text.sh $SCRATCH/originals/<evidence_no>.pdf $SCRATCH/pagetext/<evidence_no>

# 3) 폼피드 기준 페이지 분리 (extract-text.sh가 pdftotext 성공 시 자동 호출함.
#    이미지육안 판독본을 페이지별 텍스트로 만들 때는 직접 pageNN.txt 파일을 그 결과로 저장)
scripts/read/split-pages.sh $SCRATCH/pagetext/<evidence_no>/raw.txt $SCRATCH/pagetext/<evidence_no>

# 4) evidence_page_text INSERT SQL 생성 (그 다음 Supabase MCP execute_sql로 직접 실행)
scripts/read/gen-page-text-sql.sh <evidence_id> <판독방법: 글자추출|이미지육안|OCR> $SCRATCH/pagetext/<evidence_no> > $SCRATCH/pagetext/<evidence_no>.sql
```

## 각 스크립트

| 스크립트 | 역할 |
|---|---|
| `fetch-original.sh` | 매니페스트(sha256) 확인 → 없으면만 열람구에서 다운로드 |
| `extract-text.sh` | pdftotext -layout → 쪽당 30자 미만/공백이면 pdftoppm 200dpi → 그래도 부족하면 400/900dpi 재렌더 |
| `split-pages.sh` | pdftotext 결과(폼피드 `\f` 구분)를 `pageNN.txt` 파일들로 분리 |
| `gen-page-text-sql.sh` | `pageNN.txt` 전체를 `evidence_page_text` INSERT문(달러 인용)으로 변환 |

## 이미지 육안 판독 구간(자동화하지 않는 이유)

`extract-text.sh`가 렌더링까지만 하고 멈추는 지점부터는 **사람(또는 에이전트)이 이미지를
Read 도구로 직접 보고 옮겨 적어야 한다.** 이 구간을 자동 OCR로 대체하지 않는 이유는
CLAUDE.md의 신뢰등급 철학과 같다 — 기계 OCR은 한국어 공문서에서 오인식이 잦아 A등급
근거로 쓸 수 없고(참고용 `판독방법='OCR'`로만 캐시), 실제 근거로 쓰려면 "이미지육안"이어야
한다. 옮겨 적은 결과를 `pageNN.txt`에 그대로 저장한 뒤 4단계부터 이어가면 된다.
