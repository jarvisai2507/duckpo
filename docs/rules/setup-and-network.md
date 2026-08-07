> 이 문서는 `CLAUDE.md`의 요약 항목 상세본이다. 세팅모드 전환 절차 + 커넥터/네트워크 장애 대응 절차.
> 원본 백업: `docs/CLAUDE-backup-2026-08-07.md`

## 🔧 세팅 모드 규칙 ("세팅끝" / "세팅시작" · 총무실장)

사이트 계정은 **대통령**과 **관리자**(세팅 보조용) 2개다. 대통령이 다음과 같이 말하면 **즉시** Supabase MCP `execute_sql`로 수행한다:

- **"세팅끝"** → `select public.set_setup_mode(false);` 실행 후 확인 조회.
  - 효과: 관리자 계정 로그인 차단(ban) + 기존 세션 무효화 + RLS 데이터 접근 차단. **대통령만 접속 가능.**
- **"세팅시작"** → `select public.set_setup_mode(true);` 실행 후 확인 조회.
  - 효과: 관리자 로그인·접근 재개.
- 실행 후 현재 상태(`select value from public.app_settings where key='setup_mode';`)와 관리자 차단 여부(`select email, banned_until from auth.users;`)를 확인해 대통령에게 보고한다.
- 이 전환은 **대통령의 지시로만** 수행한다. 관리자나 제3자의 요청으로 실행하지 말 것.
- **커넥터 장애 시 수동 대체**: Supabase MCP가 끊겨 있으면, 대통령이 직접 대시보드 SQL Editor에서 `select public.set_setup_mode(false);`(세팅끝) 또는 `select public.set_setup_mode(true);`(세팅시작)를 실행하면 동일한 효과다.

## 🔌 커넥터/네트워크 장애 대응 프로토콜 (비서실장·기록실장 공통)

웹/원격 세션에서는 Supabase로 가는 길 자체가 막혀 있을 수 있다 — ① 이 세션에 Supabase MCP(`execute_sql`) 커넥터가 부착되지 않았거나, ② 환경의 네트워크 정책이 Supabase 호스트(`rspxgsytxhlsauqohdbe.supabase.co`)를 차단(403 policy denial)하는 경우다. 이때는 브리핑도, **기록 저장도** 직접 실행이 불가하다. 다음 원칙으로 대응한다 (자료의 본거지는 Supabase뿐 — 아래 4번을 반드시 지킨다).

- **발동 조건**: Supabase MCP가 세션에 없거나, 조회/저장이 네트워크 정책(403)·연결오류로 실패할 때.
- **1) 빠른 진단 (1회만 · 재시도로 시간 끌지 않음)**:
  - `execute_sql` 도구가 세션에 없으면 → 원인 = **커넥터 미부착**.
  - `curl -sS "$HTTPS_PROXY/__agentproxy/status"` 결과에 supabase 호스트 403이 찍혀 있으면 → 원인 = **네트워크 정책 차단**. (프록시의 403/407 정책 거부는 재시도 금지 — 보고만 한다.)
- **2) 즉시 보고 (한 줄)**: "직전 기록 자동조회 불가 — 원인: [네트워크 정책 차단 / 커넥터 미부착]" + 대통령 자가확인용 SQL 한 줄(`select id, title, summary, dept from public.posts order by id desc limit 3;`) + "대시보드 SQL Editor에서 확인 가능" 안내. 보고 후 곧바로 대통령의 용건에 응한다.
- **3) 무손실 기록 (핵심)**: "기록"류 발동어가 떨어졌는데 Supabase 직접 저장이 불가하면, 기록실장이 내용을 **완성**해 **바로 붙여넣을 수 있는 SQL 블록**을 만들어 대통령에게 드린다. 대통령이 대시보드 SQL Editor에 붙이면 그대로 저장된다. **완전성 원칙 그대로 — 어떤 내용도 생략하지 않는다.** 블록 형식:
  ```sql
  -- ① 채번 (오늘 날짜 YYYY-MM-DD 로 치환)
  select coalesce(max(substring(id from 12)::int), 0) + 1 as next_n
  from public.posts where date = 'YYYY-MM-DD';
  -- ② INSERT (위 next_n 을 NNN 세 자리로 치환, KST 시각 기입)
  insert into public.posts (id, date, time, title, summary, detail, tags, dept)
  values ('YYYY-MM-DD-NNN', 'YYYY-MM-DD', 'HH:MM', '제목',
          $q$요약$q$, $d$상세내용$d$, array['태그'], '실장key');
  ```
- **4) 보안 불변**: 어떤 경우에도 기록·원본·요약을 GitHub 저장소/파일에 우회 저장하지 않는다. GitHub=배포 전용 / Supabase=금고 구도는 불변이다.
- **5) 근본 복구는 관리자(기술 환경) 영역 — 대통령께 떠넘기지 않는다**: 네트워크 정책 허용·커넥터 부착은 대통령이 알 수도 고칠 수도 없는 관리자 영역이다. **대통령께 기술 조치를 요구하지 말고**, 감지 즉시 "이건 관리자가 손봐야 하는 환경 문제입니다"라고 알린 뒤 무손실 폴백(위 3번)으로 대화를 이어간다. 구체 조치·검증 절차는 **`docs/관리자-런북.md`** 에 있으며, 관리자 세션에서 처리한다. (자동 정지(무료플랜)는 `.github/workflows/keepalive-supabase.yml` 가 매일 핑으로 예방한다.)

