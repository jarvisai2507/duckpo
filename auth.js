/* duckpo 인증 게이트 (단일 사용자)
 * - 데이터는 전부 Supabase(RLS 잠금)에 있고, 이 파일과 publishable key는 공개되어도 안전하다.
 *   (publishable key는 공개용으로 설계된 키 — 실제 방어는 RLS가 담당)
 * - 최초 1회 등록 후에는 DB 트리거가 추가 가입을 영구 차단한다.
 */
const SUPABASE_URL = 'https://rspxgsytxhlsauqohdbe.supabase.co';
const SUPABASE_KEY = 'sb_publishable_5Nl1jCdX2nbve1rubaMilw_TyitemqA';

const sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

function gateEls() {
  return {
    gate: document.getElementById('authGate'),
    title: document.getElementById('gateTitle'),
    desc: document.getElementById('gateDesc'),
    email: document.getElementById('gateEmail'),
    pw: document.getElementById('gatePw'),
    pw2: document.getElementById('gatePw2'),
    pw2Wrap: document.getElementById('gatePw2Wrap'),
    btn: document.getElementById('gateBtn'),
    err: document.getElementById('gateErr'),
  };
}

function showErr(msg) {
  const { err } = gateEls();
  err.textContent = msg;
  err.style.display = 'block';
}

async function requireLogin(onReady) {
  const { gate } = gateEls();

  const { data: { session } } = await sb.auth.getSession();
  if (session) {
    gate.style.display = 'none';
    onReady(sb);
    return;
  }

  // 로그인 모드 vs 최초 등록 모드 판단
  let registered = true;
  try {
    const { data, error } = await sb.rpc('user_exists');
    if (!error) registered = data === true;
  } catch (_) { /* 네트워크 실패 시 로그인 모드로 폴백 */ }

  const { title, desc, pw2Wrap, btn, email, pw, pw2 } = gateEls();
  if (!registered) {
    title.textContent = '최초 등록';
    desc.textContent = '대통령 계정을 생성합니다. 이 등록은 단 한 번만 가능하며, 이후 모든 가입이 차단됩니다.';
    pw2Wrap.style.display = 'block';
    btn.textContent = '등록';
  } else {
    title.textContent = '로그인';
    desc.textContent = '등록된 계정으로 로그인하세요.';
    pw2Wrap.style.display = 'none';
    btn.textContent = '로그인';
  }

  btn.addEventListener('click', async () => {
    const e = email.value.trim(), p = pw.value;
    if (!e || !p) { showErr('이메일과 비밀번호를 입력하세요.'); return; }
    btn.disabled = true;
    try {
      if (!registered) {
        if (p.length < 8) { showErr('비밀번호는 8자 이상으로 하세요.'); btn.disabled = false; return; }
        if (p !== pw2.value) { showErr('비밀번호가 서로 다릅니다.'); btn.disabled = false; return; }
        const { data, error } = await sb.auth.signUp({ email: e, password: p });
        if (error) {
          showErr('등록이 차단되어 있습니다 (단일 사용자 사이트). 이미 등록된 계정으로 로그인하세요.');
          btn.disabled = false; return;
        }
        if (!data.session) {
          showErr('등록은 되었으나 이메일 확인이 필요합니다. Supabase 설정에서 "Confirm email"을 끈 뒤 다시 시도하세요.');
          btn.disabled = false; return;
        }
      } else {
        const { error } = await sb.auth.signInWithPassword({ email: e, password: p });
        if (error) { showErr('이메일 또는 비밀번호가 올바르지 않습니다.'); btn.disabled = false; return; }
      }
      location.reload();
    } catch (_) {
      showErr('연결에 실패했습니다. 잠시 후 다시 시도하세요.');
      btn.disabled = false;
    }
  });

  // Enter 키 지원
  [email, pw, pw2].forEach(el => el && el.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') btn.click();
  }));
}

async function duckpoLogout() {
  await sb.auth.signOut();
  location.reload();
}

window.duckpo = { sb, requireLogin, logout: duckpoLogout };
