# duckpo
덕포산업단지

## 📋 일일 기록 게시판

날짜별로 하루의 대화와 일들을 기록하는 게시판 웹사이트입니다.

**웹페이지**: https://jarvisai2507.github.io/duckpo/

### 사용법

Claude와 대화하다가 **"대화끝"** 또는 **"오늘끝"** 이라고 말하면, Claude가 그날의 대화를 요약해서 게시판에 자동으로 올립니다.

### 구조

- `index.html` — 게시판 페이지 (날짜별 그룹, 검색, 펼침/접힘)
- `logs/posts.json` — 게시글 데이터
- `.github/workflows/deploy-pages.yml` — `main` 브랜치 push 시 GitHub Pages 자동 배포
- `CLAUDE.md` — 대화 기록 규칙

### 최초 설정 (1회)

GitHub 저장소의 **Settings → Pages → Source**에서 **"GitHub Actions"** 를 선택해야 페이지가 배포됩니다.
