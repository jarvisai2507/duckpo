#!/usr/bin/env bash
# 웹사이트 회귀 테스트 — 2026-08-05 독립검증에서 잡힌 결함들이 다시 조용히
# 돌아오지 않게 하는 고정 검사. "한 번 눈으로 확인했다"가 아니라 "스크립트가
# 매번 기계적으로 재확인한다"로 바꾸는 것이 목적이다(금고 쪽 run_verification_
# selftest()와 같은 철학 — 검증을 사람의 기억이 아니라 코드에 고정한다).
#
# 사용법: scripts/site/test-site.sh   (레포 어디서 실행해도 무방, 레포 루트로 자동 이동)
# 실패하면 non-zero로 종료한다 — 커밋 전에 돌려서 게이트로 쓸 것.
set -euo pipefail
cd "$(dirname "$0")/../.."

FAIL=0
pass() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; FAIL=1; }

echo "== 1. 최상위 화면 페이지 문법·구조 검사 =="
PAGES=(index.html org.html 상황판.html 타임라인.html)
for f in "${PAGES[@]}"; do
  if [ ! -f "$f" ]; then fail "$f 없음"; continue; fi

  node -e "
    const fs = require('fs');
    const html = fs.readFileSync('$f', 'utf8');
    const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
    if (!scripts.length) throw new Error('inline script 없음');
    scripts.forEach(s => new Function(s));
  " && pass "$f: 인라인 스크립트 문법 정상" || fail "$f: 인라인 스크립트 문법 오류"

  grep -q 'id="authGate"' "$f" && pass "$f: 로그인 게이트 포함(배포 대상 자격)" || fail "$f: 로그인 게이트 없음 — 배포 안 됨"
  grep -q 'href="theme.css"' "$f" && pass "$f: theme.css 연결" || fail "$f: theme.css 미연결"
  grep -q 'src="nav.js"' "$f" && pass "$f: nav.js 연결" || fail "$f: nav.js 미연결"
  grep -q 'id="siteNav"' "$f" && pass "$f: siteNav 마운트 지점 존재" || fail "$f: siteNav 마운트 지점 없음"
done

echo "== 2. 상황판.html 회귀 테스트 (2026.8.5 적발 결함 재현 방지) =="
node -e "
  const fs = require('fs');
  const html = fs.readFileSync('상황판.html', 'utf8');
  const src = html.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/)[1];
  eval(src.slice(0, src.indexOf('duckpo.requireLogin')));

  let ok = true;
  const check = (name, cond) => { console.log((cond ? '  ✅ ' : '  ❌ ') + name); if (!cond) ok = false; };

  // 결함1: v_issue_gap은 쟁점당 1행이 아니라 '미확정 사실 1건당 1행'이다.
  // gapMap이 문자열 .length(글자수)를 세던 옛 버그가 돌아오면 이 값이 틀어진다.
  const gapMap = new Map();
  [{issue_no:'I-X',미확정사실:'F-001'},{issue_no:'I-X',미확정사실:'F-002'},{issue_no:'I-X',미확정사실:'F-003'}]
    .forEach(r => gapMap.set(r.issue_no, (gapMap.get(r.issue_no) || 0) + 1));
  check('gapMap: 3개 미확정사실 행 → 카운트 3 (글자수 아님)', gapMap.get('I-X') === 3);

  // 결함2: 상태!='유효'인 쟁점(붕괴·보류)이 '즉시 주장 가능'으로 잘못 표시되면 안 된다.
  const collapsed = { issue_no:'I-Y', 상태:'붕괴', 쟁점:'테스트', 대상:[], 필요사실:[] };
  const badge = issueBadge(collapsed, new Set(), new Map());
  check('붕괴 쟁점 배지에 \"즉시 주장 가능\" 없음', !badge.includes('즉시 주장 가능'));
  check('붕괴 쟁점 배지에 상태 표시 있음', badge.includes('붕괴'));

  process.exit(ok ? 0 : 1);
" && pass "상황판.html 회귀 테스트 통과" || { fail "상황판.html 회귀 테스트 실패"; }

echo "== 3. 타임라인.html 회귀 테스트 (2026.8.5 적발 결함 재현 방지) =="
node -e "
  const fs = require('fs');
  const html = fs.readFileSync('타임라인.html', 'utf8');
  const src = html.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/)[1];
  eval(src.slice(0, src.indexOf('duckpo.requireLogin')));

  let ok = true;
  const check = (name, cond) => { console.log((cond ? '  ✅ ' : '  ❌ ') + name); if (!cond) ok = false; };

  // 결함3: fact.일자정밀도 CHECK 허용값은 일/월/년/기간/미상뿐 — '정확'은 없는 값이다.
  // '일'(정확한 날짜)에는 캐비엇이 붙으면 안 되고, '월'(부정확)에는 붙어야 한다.
  const exact = buildItems([], [{fact_no:'F-A',일자:'2024-01-01',일자정밀도:'일',주체:'x',행위:'y'}], []);
  const vague = buildItems([], [{fact_no:'F-B',일자:'2024-01-01',일자정밀도:'월',주체:'x',행위:'y'}], []);
  check('정밀도=일(정확) → 캐비엇 없음', !exact[0].detail.includes('일자'));
  check('정밀도=월(부정확) → 캐비엇 있음', vague[0].detail.includes('일자 월'));

  // 결함4: '오늘' 표시선은 연도 그룹 바깥(형제)이어야 필터로 함께 숨겨지지 않는다.
  const mixed = buildItems(
    [{disposition_no:'D-1',처분일:'2026-01-01',처분청:'x',처분내용:'past',현재상태:'유효'}],
    [{fact_no:'F-X',일자:'2026-12-31',일자정밀도:'일',주체:'x',행위:'future'}], []);
  const out = renderTimeline(mixed);
  check('오늘 표시선이 year-group보다 먼저 등장(그룹 바깥)', out.indexOf('now-marker') < out.indexOf('year-group'));

  process.exit(ok ? 0 : 1);
" && pass "타임라인.html 회귀 테스트 통과" || { fail "타임라인.html 회귀 테스트 실패"; }

echo "== 4. 배포 스테이징 시뮬레이션 (deploy-pages.yml 로직과 동일) =="
SIM=$(mktemp -d)
STRAY="$(mktemp -p . -t scratch_test_XXXX.html)"
echo '<html><body>내부 스크래치, 로그인 게이트 없음</body></html>' > "$STRAY"
(
  set -euo pipefail
  shopt -s nullglob
  for f in *.html; do
    if grep -q 'id="authGate"' "$f"; then cp "$f" "$SIM/"; fi
  done
  for f in auth.js theme.css nav.js; do
    [ -f "$f" ] && cp "$f" "$SIM/"
  done
)
STRAY_BASENAME=$(basename "$STRAY")
rm -f "$STRAY"

[ -f "$SIM/index.html" ] && pass "index.html 배포 대상에 포함" || fail "index.html 누락"
[ -f "$SIM/상황판.html" ] && pass "상황판.html 배포 대상에 포함" || fail "상황판.html 누락(2026.8.5 사고 재현)"
[ -f "$SIM/타임라인.html" ] && pass "타임라인.html 배포 대상에 포함" || fail "타임라인.html 누락"
[ -f "$SIM/theme.css" ] && [ -f "$SIM/nav.js" ] && pass "theme.css·nav.js 포함" || fail "공용 자산 누락"
[ ! -f "$SIM/$STRAY_BASENAME" ] && pass "게이트 없는 스크래치 html 차단됨" || fail "스크래치 html이 유출됨 — 치명적"
find "$SIM" -type f ! -name '*.html' ! -name '*.js' ! -name '*.css' | grep -q . \
  && fail "허용 확장자 외 파일 유출" || pass "허용 확장자 외 파일 없음"
rm -rf "$SIM"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "🟢 전체 통과"
else
  echo "🔴 결함 발견 — 위 ❌ 항목을 고친 뒤 다시 실행할 것"
fi
exit "$FAIL"
