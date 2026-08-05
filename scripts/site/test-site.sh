#!/usr/bin/env bash
# 웹사이트 회귀 테스트 — 2026-08-05 두 차례 독립검증에서 잡힌 결함들이 다시
# 조용히 돌아오지 않게 하는 고정 검사. "한 번 눈으로 확인했다"가 아니라
# "스크립트가 매번 기계적으로 재확인한다"로 바꾸는 것이 목적이다(금고 쪽
# run_verification_selftest()와 같은 철학).
#
# 2차 독립검증에서 이 스크립트 자체의 결함도 지적됐다 — 회귀검사 하나가
# requireLogin 콜백 안에 있던 로직을 그대로 복제해 재작성한 사본을 검사하고
# 있어(진짜 코드는 건드리지 않음), 원래 버그를 그대로 되살려도 통과했다.
# 그래서 그 로직을 상황판.html에서 최상위 함수(buildGapMap)로 뺐고, 이
# 스크립트는 그 실제 함수를 evel로 불러와 검사한다.
#
# 사용법: scripts/site/test-site.sh   (레포 어디서 실행해도 무방, 레포 루트로 자동 이동)
# 실패하면 non-zero로 종료한다 — auto-publish.yml이 머지 전에 이 스크립트를
# 게이트로 돌린다(2026.8.5 2차 독립검증 지적 — 검사는 강제해야 의미가 있다).
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

  grep -q 'id="authGate"' "$f" && pass "$f: 로그인 게이트 포함" || fail "$f: 로그인 게이트 없음"
  grep -q 'href="theme.css"' "$f" && pass "$f: theme.css 연결" || fail "$f: theme.css 미연결"
  grep -q 'src="nav.js"' "$f" && pass "$f: nav.js 연결" || fail "$f: nav.js 미연결"
  grep -q 'id="siteNav"' "$f" && pass "$f: siteNav 마운트 지점 존재" || fail "$f: siteNav 마운트 지점 없음"
done

echo "== 2. 페이지 목록 정합성 (deploy-pages.yml · nav.js · 이 스크립트 3곳) =="
# 2026.8.5 2차 독립검증: 페이지 목록이 세 곳(배포 매니페스트·네비게이션·
# 이 테스트)에 따로 적혀 있어 하나만 고치고 나머지를 잊으면 조용히
# 어긋난다. 매번 세 곳을 실제로 대조한다.
PAGES_STR="${PAGES[*]}"
python3 -c "
import re, sys
yml = open('.github/workflows/deploy-pages.yml', encoding='utf-8').read()
m = re.search(r'PAGES=\(([^)]*)\)', yml)
if not m:
    print('  ❌ deploy-pages.yml에서 PAGES=(...) 를 찾지 못함'); sys.exit(1)
yml_pages = set(m.group(1).split())

navjs = open('nav.js', encoding='utf-8').read()
nav_pages = set(re.findall(r\"href:\s*'([^']+\.html)'\", navjs))

script_pages = set('''${PAGES_STR}'''.split())

if yml_pages == nav_pages == script_pages:
    print('  ✅ 페이지 목록 일치:', sorted(yml_pages))
else:
    print('  ❌ 페이지 목록 불일치')
    print('     deploy-pages.yml:', sorted(yml_pages))
    print('     nav.js          :', sorted(nav_pages))
    print('     test-site.sh    :', sorted(script_pages))
    sys.exit(1)
" && pass "페이지 목록 3곳 정합" || fail "페이지 목록 3곳 불일치 — 위 상세 참고"

echo "== 3. 상황판.html 회귀 테스트 (2026.8.5 적발 결함 재현 방지) =="
node -e "
  const fs = require('fs');
  const html = fs.readFileSync('상황판.html', 'utf8');
  const src = html.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/)[1];
  eval(src.slice(0, src.indexOf('duckpo.requireLogin')));

  let ok = true;
  const check = (name, cond) => { console.log((cond ? '  ✅ ' : '  ❌ ') + name); if (!cond) ok = false; };

  // 결함1: v_issue_gap은 쟁점당 1행이 아니라 '미확정 사실 1건당 1행'이다.
  // buildGapMap이 문자열 .length(글자수)를 세던 옛 버그가 돌아오면 이 값이
  // 틀어진다. ★실제 함수를 호출한다(사본을 재작성해 검사하지 않는다).
  const gapMap = buildGapMap([
    {issue_no:'I-X',미확정사실:'F-001'},
    {issue_no:'I-X',미확정사실:'F-002'},
    {issue_no:'I-X',미확정사실:'F-003'},
  ]);
  check('buildGapMap: 3개 미확정사실 행 → 카운트 3 (글자수 아님)', gapMap.get('I-X') === 3);

  // 결함2: 상태!='유효'인 쟁점이 '즉시 주장 가능'으로 잘못 표시되면 안 된다.
  // 진짜로 일어날 수 있는 경로는 '보류'다 — '붕괴'는 v_issue_ready가
  // 상태='유효'만 보므로 애초에 readySet에 들 수 없지만, '보류'는
  // v_issue_gap이 상태 IN ('유효','보류')를 보므로 gapMap에 얼마든지
  // 실제로 잡힐 수 있다(2026.8.5 2차 독립검증 — 이전 테스트는 붕괴 쟁점을
  // 빈 Set·빈 Map에 넣어 애초에 도달 불가능한 경로만 확인하고 있었다).
  const onHold = { issue_no:'I-Y', 상태:'보류', 쟁점:'테스트', 대상:[], 필요사실:['F-009'] };
  const holdBadge = issueBadge(onHold, new Set(), buildGapMap([{issue_no:'I-Y',미확정사실:'F-009'}]));
  check('보류 쟁점 배지에 \"즉시 주장 가능\" 없음', !holdBadge.includes('즉시 주장 가능'));
  check('보류 쟁점 배지에 상태 표시 있음', holdBadge.includes('보류'));

  const collapsed = { issue_no:'I-Z', 상태:'붕괴', 쟁점:'테스트', 대상:[], 필요사실:[] };
  const collapsedBadge = issueBadge(collapsed, new Set(), new Map());
  check('붕괴 쟁점 배지에 \"즉시 주장 가능\" 없음', !collapsedBadge.includes('즉시 주장 가능'));

  // 결함(신규): 상태='유효'인데 필요사실이 비어 있으면 ready/gap 어느 뷰에도
  // 안 잡힌다 — '모른다'가 아니라 '논거 미등재'로 구분해 표시해야 한다.
  const noFacts = { issue_no:'I-W', 상태:'유효', 쟁점:'테스트', 대상:[], 필요사실:[] };
  const noFactsBadge = issueBadge(noFacts, new Set(), new Map());
  check('필요사실 0건 쟁점은 \"필요사실 미등재\"로 구분 표시', noFactsBadge.includes('필요사실 미등재'));

  process.exit(ok ? 0 : 1);
" && pass "상황판.html 회귀 테스트 통과" || { fail "상황판.html 회귀 테스트 실패"; }

echo "== 4. 타임라인.html 회귀 테스트 (2026.8.5 적발 결함 재현 방지) =="
node -e "
  const fs = require('fs');
  const html = fs.readFileSync('타임라인.html', 'utf8');
  const src = html.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/)[1];
  eval(src.slice(0, src.indexOf('duckpo.requireLogin')));

  let ok = true;
  const check = (name, cond) => { console.log((cond ? '  ✅ ' : '  ❌ ') + name); if (!cond) ok = false; };

  // 결함3: fact.일자정밀도 CHECK 허용값은 일/월/년/기간/미상뿐 — '정확'은 없는 값이다.
  const exact = buildItems([], [{fact_no:'F-A',일자:'2024-01-01',일자정밀도:'일',주체:'x',행위:'y'}], []);
  const vague = buildItems([], [{fact_no:'F-B',일자:'2024-01-01',일자정밀도:'월',주체:'x',행위:'y'}], []);
  check('정밀도=일(정확) → 캐비엇 없음', !exact[0].detail.includes('일자'));
  check('정밀도=월(부정확) → 캐비엇 있음', vague[0].detail.includes('일자 월'));

  // 결함4(1차 수정) + 결함4-재발(2차 독립검증 적발): '오늘' 표시선을
  // 연도 경계로 옮겼더니 그 해에 이미 지난 일이 여럿 있어도 전부 표시선
  // 아래(미래)로 깔리는 문제가 새로 생겼다. 시스템 시계 대신 명시적
  // 기준일(todayOverride)을 넘겨 하드코딩 연도에 의존하지 않게 한다
  // (2027년부터 이 테스트가 조용히 깨지던 문제도 함께 해소).
  const REF = '2026-06-15';
  const precise = buildItems(
    [
      {disposition_no:'D-1',처분일:'2026-01-01',처분청:'x',처분내용:'과거1',현재상태:'유효'},
      {disposition_no:'D-2',처분일:'2026-06-01',처분청:'x',처분내용:'과거2',현재상태:'유효'},
    ],
    [{fact_no:'F-X',일자:'2026-12-31',일자정밀도:'일',주체:'x',행위:'미래'}],
    []
  );
  const out = renderTimeline(precise, REF);
  const idxPast2 = out.indexOf('과거2');
  const idxMarker = out.indexOf('now-marker');
  const idxFuture = out.indexOf('미래');
  check('오늘 표시선이 정확한 날짜 위치(과거2 뒤·미래 앞)에 있음 — 연도 경계 아님',
        idxPast2 !== -1 && idxMarker !== -1 && idxFuture !== -1 && idxPast2 < idxMarker && idxMarker < idxFuture);

  // groupVisible: 필터로 그 연도 항목이 전부 가려져도 '오늘' 표시선이 있으면
  // 그룹 자체는 유지되어야 한다(순수 함수라 DOM 없이 검사 가능).
  check('groupVisible(항목없음, 표시선있음) → true', groupVisible(false, true) === true);
  check('groupVisible(항목없음, 표시선없음) → false', groupVisible(false, false) === false);
  check('groupVisible(항목있음, 표시선없음) → true', groupVisible(true, false) === true);

  process.exit(ok ? 0 : 1);
" && pass "타임라인.html 회귀 테스트 통과" || { fail "타임라인.html 회귀 테스트 실패"; }

echo "== 5. 배포 스테이징 시뮬레이션 (deploy-pages.yml의 명시적 매니페스트와 동일 로직) =="
# 이제는 목록에 있는 파일만 이름으로 복사하므로(글롭도 문자열 스니핑도
# 아님) "스크래치 파일이 섞이는지"는 구조적으로 재현 불가능하다 — 대신
# "목록에 있는 게 전부, 정확히 그만큼만 배포되는가"를 확인한다.
SIM=$(mktemp -d)
trap 'rm -rf "$SIM"' EXIT
ASSETS=(auth.js theme.css nav.js)
(
  set -euo pipefail
  for f in "${PAGES[@]}" "${ASSETS[@]}"; do
    cp "$f" "$SIM/"
  done
)
EXPECTED=$(( ${#PAGES[@]} + ${#ASSETS[@]} ))
ACTUAL=$(find "$SIM" -type f | wc -l)

[ -f "$SIM/index.html" ] && pass "index.html 배포 대상에 포함" || fail "index.html 누락"
[ -f "$SIM/상황판.html" ] && pass "상황판.html 배포 대상에 포함" || fail "상황판.html 누락(2026.8.5 1차 사고 재현)"
[ -f "$SIM/타임라인.html" ] && pass "타임라인.html 배포 대상에 포함" || fail "타임라인.html 누락"
[ -f "$SIM/theme.css" ] && [ -f "$SIM/nav.js" ] && pass "theme.css·nav.js 포함" || fail "공용 자산 누락"
[ "$ACTUAL" -eq "$EXPECTED" ] && pass "배포 파일 수 정확히 일치(${ACTUAL}/${EXPECTED})" \
  || fail "배포 파일 수 불일치(${ACTUAL}/${EXPECTED})"
EXTRA=$(find "$SIM" -type f ! -name '*.html' ! -name '*.js' ! -name '*.css' | wc -l)
[ "$EXTRA" -eq 0 ] && pass "허용 확장자 외 파일 없음" || fail "허용 확장자 외 파일 ${EXTRA}건 유출"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "🟢 전체 통과"
else
  echo "🔴 결함 발견 — 위 ❌ 항목을 고친 뒤 다시 실행할 것"
fi
exit "$FAIL"
