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

### 최초 설정 (1회)

GitHub 저장소의 **Settings → Pages → Source**에서 **"GitHub Actions"** 를 선택해야 페이지가 배포됩니다.
