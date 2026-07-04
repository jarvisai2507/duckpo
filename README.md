# duckpo
덕포산업단지

## 📋 일일 기록 게시판

날짜별로 하루의 대화와 일들을 기록하는 게시판 웹사이트입니다.

**웹페이지**: https://jarvisai2507.github.io/duckpo/

### 사용법

Claude와 대화하다가 **"대화끝"** 또는 **"오늘끝"** 이라고 말하면, Claude가 그날의 대화를 요약해서 게시판에 자동으로 올립니다.

### 구조

- `index.html` — 게시판 페이지 (날짜별 그룹, 검색, 펼침/접힘, 실장별 필터)
- `org.html` — 조직도 페이지 (실장 체계 시각화 + 실장별 기록 건수)
- `logs/posts.json` — 게시글 데이터
- `.github/workflows/auto-publish.yml` — 작업 브랜치(`claude/**`) push 시 자동으로 `main`에 머지
- `.github/workflows/deploy-pages.yml` — `main` 갱신(머지 완료 또는 직접 push) 시 GitHub Pages 자동 배포
- `CLAUDE.md` — 조직 체계 정의 & 대화 기록 규칙

### 자동 공개 흐름

작업 브랜치(`claude/**`)에 커밋이 push되면 → `auto-publish.yml`이 `main`에 자동 머지 → 완료 후 `deploy-pages.yml`이 이어받아 GitHub Pages에 배포합니다. 즉 **"대화끝" 기록이 별도 조작 없이 웹사이트에 자동 공개**됩니다.

### 최초 설정 (1회) — Pages 켜기

GitHub 정책상 이 스위치는 저장소 소유자만 켤 수 있습니다. 아래 **둘 중 아무 방법이나 한 번만** 하면, 이후 배포는 전부 자동입니다.

- **방법 A (추천)**: 저장소 **Settings → Pages → Build and deployment → Source** 드롭다운에서 **`GitHub Actions`** 선택 (별도 저장 버튼 없음 — 선택 즉시 적용)
- **방법 B**: 같은 화면에서 Source를 **`Deploy from a branch`** 로 두고 **Branch: `main` / `(root)`** 선택 후 **Save**

어느 쪽이든 자동배포 파이프라인(`auto-publish.yml` → `deploy-pages.yml`)이 그대로 동작합니다. 설정 후 잠시 뒤 화면 상단에 "Your site is live at …" 안내가 뜨면 완료입니다.
