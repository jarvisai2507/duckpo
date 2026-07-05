/* duckpo 인증 게이트 (대통령 + 관리자, 최대 2인)
 * - 데이터는 전부 Supabase(RLS 잠금)에 있고, 이 파일과 publishable key는 공개되어도 안전하다.
 *   (publishable key는 공개용으로 설계된 키 — 실제 방어는 RLS가 담당)
 * - 등록은 대통령 1명 + 관리자 1명만 가능. 그 이후 모든 가입은 DB 트리거가 영구 차단.
 * - "세팅끝" 상태에서는 관리자 로그인·데이터 접근이 차단된다 ("세팅시작"으로 재개).
 */
const SUPABASE_URL = 'https://rspxgsytxhlsauqohdbe.supabase.co';
const SUPABASE_KEY = 'sb_publishable_5Nl1jCdX2nbve1rubaMilw_TyitemqA';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

const ROLE_LABEL = { president: '🏛️ 대통령', admin: '🛠️ 관리자' };

function els() {
  const g = id => document.getElementById(id);
  return {
    gate: g('authGate'), title: g('gateTitle'), desc: g('gateDesc'),
    roles: g('gateRoles'), roleP: g('roleP'), roleA: g('roleA'),
    form: g('gateForm'), email: g('gateEmail'), pw: g('gatePw'),
    pw2: g('gatePw2'), pw2Wrap: g('gatePw2Wrap'),
    btn: g('gateBtn'), sw: g('gateSwitch'), err: g('gateErr'),
  };
}

function showErr(msg) {
  const { err } = els();
  err.textContent = msg;
  err.style.display = 'block';
}
function clearErr() {
  const { err } = els();
  err.style.display = 'none';
}

let mode = 'login';        // 'login' | 'register'
let regRole = null;        // 'president' | 'admin'
let status = { president: true, admin: true };

function showLogin() {
  mode = 'login'; regRole = null; clearErr();
  const e = els();
  e.title.textContent = '로그인';
  e.desc.textContent = '등록된 계정으로 로그인하세요.';
  e.roles.style.display = 'none';
  e.form.style.display = 'block';
  e.pw2Wrap.style.display = 'none';
  e.btn.textContent = '로그인';
  const anyOpen = !status.president || !status.admin;
  e.sw.style.display = anyOpen ? 'inline' : 'none';
  e.sw.textContent = '최초 등록으로 돌아가기';
}

function showChooser() {
  mode = 'register'; regRole = null; clearErr();
  const e = els();
  e.title.textContent = '최초 등록';
  e.desc.textContent = '등록할 직책을 선택하세요. 각 직책은 단 한 번만 등록할 수 있습니다.';
  e.roles.style.display = 'flex';
  e.roleP.style.display = status.president ? 'none' : 'block';
  e.roleA.style.display = status.admin ? 'none' : 'block';
  e.form.style.display = 'none';
  e.sw.style.display = 'inline';
  e.sw.textContent = '이미 등록된 계정으로 로그인';
}

function showRegister(role) {
  mode = 'register'; regRole = role; clearErr();
  const e = els();
  e.title.textContent = ROLE_LABEL[role] + ' 등록';
  e.desc.textContent = role === 'president'
    ? '대통령 계정을 생성합니다. 최종 의사결정권자 계정입니다.'
    : '관리자 계정을 생성합니다. 세팅 종료 후에는 대통령이 접속을 차단할 수 있습니다.';
  e.roles.style.display = 'none';
  e.form.style.display = 'block';
  e.pw2Wrap.style.display = 'block';
  e.btn.textContent = '등록';
  e.sw.style.display = 'inline';
  e.sw.textContent = '직책 다시 선택';
}

async function requireLogin(onReady) {
  const e = els();

  const { data: { session } } = await sb.auth.getSession();
  if (session) {
    e.gate.style.display = 'none';
    onReady(sb);
    return;
  }

  // 등록 현황 조회 → 화면 모드 결정
  try {
    const { data, error } = await sb.rpc('registration_status');
    if (!error && data) status = data;
  } catch (_) { /* 실패 시 로그인 모드 폴백 */ }

  if (!status.president || !status.admin) showChooser();
  else showLogin();

  e.roleP.addEventListener('click', () => showRegister('president'));
  e.roleA.addEventListener('click', () => showRegister('admin'));
  e.sw.addEventListener('click', ev => {
    ev.preventDefault();
    if (mode === 'login') showChooser();
    else if (regRole) showChooser();
    else showLogin();
  });

  e.btn.addEventListener('click', async () => {
    const em = e.email.value.trim(), p = e.pw.value;
    if (!em || !p) { showErr('이메일과 비밀번호를 입력하세요.'); return; }
    e.btn.disabled = true;
    try {
      if (mode === 'register' && regRole) {
        if (p.length < 8) { showErr('비밀번호는 8자 이상으로 하세요.'); e.btn.disabled = false; return; }
        if (p !== e.pw2.value) { showErr('비밀번호가 서로 다릅니다.'); e.btn.disabled = false; return; }
        const { data, error } = await sb.auth.signUp({
          email: em, password: p,
          options: { data: { role: regRole } }
        });
        if (error) {
          showErr('등록할 수 없습니다 — 해당 직책이 이미 등록되었거나 가입이 차단된 상태입니다.');
          e.btn.disabled = false; return;
        }
        if (!data.session) {
          showErr('등록은 되었으나 이메일 확인이 필요합니다. Supabase 설정에서 "Confirm email"을 끈 뒤 다시 시도하세요.');
          e.btn.disabled = false; return;
        }
      } else {
        const { error } = await sb.auth.signInWithPassword({ email: em, password: p });
        if (error) {
          const m = (error.message || '').toLowerCase();
          if (m.includes('banned')) {
            showErr('접속이 차단된 계정입니다 (세팅 종료 상태). 대통령이 "세팅시작"을 선언하면 다시 접속할 수 있습니다.');
          } else {
            showErr('이메일 또는 비밀번호가 올바르지 않습니다.');
          }
          e.btn.disabled = false; return;
        }
      }
      location.reload();
    } catch (_) {
      showErr('연결에 실패했습니다. 잠시 후 다시 시도하세요.');
      e.btn.disabled = false;
    }
  });

  // Enter 키 지원
  [e.email, e.pw, e.pw2].forEach(el => el && el.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') e.btn.click();
  }));
}

async function duckpoLogout() {
  await sb.auth.signOut();
  location.reload();
}

window.duckpo = { sb, requireLogin, logout: duckpoLogout };
